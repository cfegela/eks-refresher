#!/bin/bash
# from: https://aws.plainenglish.io/navigate-aws-eks-with-fargate-a-hands-on-project-guide-to-seamless-kubernetes-deployment-and-39bae6600127
# note: the above required a correction to the iam policy for the awslbc to work. this fix is refelected in the policy document in this repo

# install tools
echo "installing required tools..."
brew install kubectl eksctl helm k9
sleep 5

# set up the cluster
echo "setting up cluster..."
eksctl create cluster --region us-east-2 --name kate --fargate
sleep 15

# apply configs
echo "applying configs..."
kubectl apply -f config.yaml
sleep 120

# confirm
echo "checking configs..."
kubectl get all
kubectl get ingress
sleep 15

# approve oidc connector
echo "apprving oidc connection..."
eksctl utils associate-iam-oidc-provider --cluster kate --region us-east-2 --approve
sleep 5

# create iam role and policy
echo "creating iam resources..."
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --region us-east-2 --policy-document file://lbc-iam-policy.json
sleep 5
eksctl create iamserviceaccount \
  --cluster=kate \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::620743043986:policy/AWSLoadBalancerControllerIAMPolicy \
  --region us-east-2 \
  --approve
sleep 10

# install load balancer controller
echo "installing aws load balancer controller (awslbc)..."
vpcid=$(aws ec2 describe-vpcs --region us-east-2 --filters Name=tag:Name,Values=eksctl-kate-cluster* | grep VpcId | cut -d"\"" -f4)
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=kate --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller --set region=us-east-2 --set vpcId=${vpcid}

# wait for lbc's to be active
echo "waiting for lbc's to activate..."
sleep 120
kubectl get ingress

