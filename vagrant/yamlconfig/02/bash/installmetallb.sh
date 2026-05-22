#!/bin/sh

helm repo add metallb https://metallb.github.io/metallb
helm repo update

helm install metallb metallb/metallb -n metallb-system --create-namespace --version 0.15.3

