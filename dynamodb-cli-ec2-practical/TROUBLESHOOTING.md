# Troubleshooting

## `Unable to locate credentials`
- On the student computer, check the named profile: `aws configure list --profile dynamodb-student`.
- Confirm you ran `aws configure --profile dynamodb-student`.
- On EC2, do not configure user keys. Check that the instance has the correct IAM role attached and that the instance profile is associated.

## `AccessDeniedException`
- Run `aws sts get-caller-identity` to verify which identity is active.
- Confirm the IAM policy placeholders `REGION` and `ACCOUNT_ID` were replaced.
- Confirm the table is in the same Region and is named exactly `StudentsLab`.
- EC2 role is intentionally allowed to access items only; it cannot create/delete the table.

## `ResourceNotFoundException`
- Check table name and Region:
  `aws dynamodb describe-table --table-name StudentsLab --region ap-south-1`
- Wait for the table to become active after creation.

## `ValidationException` or key errors
- DynamoDB keys must match the table schema exactly.
- This lab uses `student_id` with type String (`S`) as the partition key.
- Every `get-item`, `update-item`, and `delete-item` key must include `student_id`.

## `aws` command not found
- Confirm AWS CLI v2 installation with `aws --version`.
- Follow the official installation guide: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

## EC2 gets `AccessDenied` but student CLI works
- Check that `EC2DynamoDBLabRole` is attached to the instance through an instance profile.
- Verify `aws sts get-caller-identity` on EC2 shows an assumed-role ARN.
- Verify the role policy's table ARN has the correct account ID and Region.
- IAM policy changes may take a short time to propagate.

## EC2 cannot reach DynamoDB endpoint
- Check outbound HTTPS (TCP 443).
- A private subnet generally needs a NAT gateway or a DynamoDB VPC endpoint.
- Security groups are stateful; NACLs are stateless. Ensure network rules allow the required traffic.
