# CREATE IAM ROLE
resource "aws_iam_role" "iam_role" {
  name = "${local.resource_prefix}-role-${data.terraform_remote_state.vpc.aws_region_shortname}"
  path = "/service-role/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "ec2.amazonaws.com"
        }
    }
    ]
}
EOF
}

# CREATE IAM ROLE POLICY
resource "aws_iam_role_policy" "iam_role_policy" {
  name = "${aws_iam_role.iam_role.name}-policy"
  role = "${aws_iam_role.iam_role.name}"

  policy = <<EOF
{
   "Version":"2012-10-17",
   "Statement": [
      {
         "Effect":"Allow",
         "Action": [
            "ssm:DescribeParameters"
         ],
         "Resource": [
            "*"
         ]
      },
      {
         "Effect":"Allow",
         "Action": [
            "ssm:GetParameter",
            "ssm:GetParameters",
            "ssm:GetParameterHistory",
            "ssm:GetParametersByPath"
         ],
         "Resource": [
            "arn:aws:ssm:${var.aws_region}:${data.terraform_remote_state.account.aws_account_id}:parameter/ops*"
         ]
      },
      {
         "Effect":"Allow",
         "Action": [
            "kms:Decrypt"
         ],
         "Resource": [
            "arn:aws:kms:${var.aws_region}:${data.terraform_remote_state.account.aws_account_id}:key/alias/aws/ssm"
         ]
      }
   ]
}
EOF
}

# CREATE INSTANCE PROFILE
resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "${aws_iam_role.iam_role.name}-instance-profile"
  role = "${aws_iam_role.iam_role.name}"
}
