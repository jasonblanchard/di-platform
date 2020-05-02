#!/bin/bash

aws s3 cp s3://di-kubeconfig/kubeconfig ~/.kube/di-aws
export KUBECONFIG=~/.kube/di-aws
