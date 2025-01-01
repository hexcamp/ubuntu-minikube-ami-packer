AMI=ami-075e1c8bf515567ad

export AWS_REGION=us-west-1
export AWS_PROFILE=default

aws ec2 describe-images --image-ids $AMI
