#!/usr/bin/env bash

set -eo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

if [[ -z ${GITHUB_USER} ]]; then
  echo "We recommend to create a new github organization for all your gitops repos"
  echo "Setup a new organization on github https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/creating-a-new-organization-from-scratch"
  echo "Please set the environment variable GITHUB_USER when running the script like:"
  echo "GITHUB_USER=acme-org OUTPUT_DIR=gitops-production ./bootstrap.sh"

  exit 1
fi

if [[ -z ${OUTPUT_DIR} ]]; then
  echo "Please set the environment variable OUTPUT_DIR when running the script like:"
  echo "GITHUB_USER=acme-org OUTPUT_DIR=gitops-production ./bootstrap.sh"

  exit 1
fi
mkdir -p "${OUTPUT_DIR}"

install_pipelines () {
  echo "Installing OpenShift Pipelines Operator"
  oc apply -n openshift-operators -f bootstrap/ocp47/pipelines/openshift-pipelines-operator.yaml
}

install_argocd () {
    echo "Installing OpenShift GitOps Operator for OpenShift v4.7"

    oc apply -f bootstrap/ocp47/gitops/
    while ! kubectl wait --for=condition=Established crd applications.argoproj.io 2>/dev/null; do sleep 30; done

    pushd ${OUTPUT_DIR}
    while ! oc extract secrets/openshift-gitops-cluster --keys=admin.password -n openshift-gitops --to=- 2>/dev/null; do sleep 30; done
    popd
}

deploy_bootstrap_argocd () {
  echo "Deploying top level bootstrap ArgoCD Application for cluster profile ${GITOPS_PROFILE}"
  pushd ${OUTPUT_DIR}
  oc apply -n openshift-gitops -f cluster-state/
  popd
}

# main

install_pipelines

install_argocd

deploy_bootstrap_argocd

exit 0



