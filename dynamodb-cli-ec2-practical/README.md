# AWS DynamoDB CLI + EC2 IAM Role Practical

A beginner-friendly, step-by-step lab for students to:
1. Configure AWS CLI access for a dedicated IAM lab user.
2. Create a DynamoDB table from the CLI.
3. Perform CRUD operations (Create, Read, Update, Delete).
4. Create an EC2 IAM role that can access only the lab table.
5. Verify that EC2 gets temporary credentials from its role—no access keys stored on EC2.
6. Clean up resources.

> **Cost and safety:** DynamoDB and EC2 may incur charges. Use a training account, choose one AWS Region, do not use root access keys, and delete resources after the lab. Never commit credentials to Git.

## Lab architecture

```text
Student terminal
  AWS CLI profile: dynamodb-student
  Dedicated IAM user + least-privilege lab policy
          |
          | HTTPS / AWS API
          v
     Amazon DynamoDB
     Table: StudentsLab
          ^
          | HTTPS / AWS API
          |
EC2 instance (Amazon Linux 2023 / RHEL)
  Instance profile
    -> EC2DynamoDBLabRole
       -> EC2DynamoDBLabPolicy
  Uses temporary role credentials; no access keys on EC2
```

## Prerequisites

- An AWS account and permission to create IAM users/policies/roles, EC2 instances, and DynamoDB tables. Ideally, an instructor/admin creates the IAM identities for students.
- AWS CLI v2 installed on the student's computer.
- One Region selected for all steps (examples use `ap-south-1`, Mumbai).
- Basic terminal and JSON familiarity.

Official references:
- AWS CLI setup: https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
- DynamoDB CLI: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-dynamodb.html
- DynamoDB getting started: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GettingStartedDynamoDB.html
- EC2 IAM roles: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html

## Repository map

```text
dynamodb-cli-ec2-practical/
├── README.md
├── policies/
│   ├── student-cli-policy.json
│   ├── ec2-trust-policy.json
│   └── ec2-dynamodb-policy-template.json
├── commands/
│   ├── 01-check-cli.sh
│   ├── 02-create-table.sh
│   ├── 03-crud-operations.sh
│   ├── 04-query-scan.sh
│   └── 05-cleanup.sh
├── sample-data/
│   └── student-001.json
└── TROUBLESHOOTING.md
```

---

## Part 1 — Install and verify AWS CLI v2

### Amazon Linux 2023 / RHEL (x86_64)

```bash
sudo dnf install -y curl unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
aws --version
```

For ARM/Graviton EC2, use the `aarch64` installer URL from the official AWS CLI installation guide.

If `aws --version` shows AWS CLI v1 or an older package, follow the official AWS CLI v2 update/removal instructions.

## Part 2 — Create a dedicated IAM CLI user

**Instructor/admin step:** In IAM, create a lab user such as `student-dynamodb-cli`. Grant only the policy in `policies/student-cli-policy.json`, after replacing `REGION` and `ACCOUNT_ID` in the policy. This policy permits creating/deleting tables for the lab and CRUD/query operations on only `StudentsLab`.

For classroom environments, prefer IAM Identity Center or temporary credentials where available. If using an IAM user access key for this introductory exercise:
- Create an access key only for the dedicated lab user—not root.
- Never paste it into a repo, chat, screenshot, or shared terminal.
- Revoke/delete the key after the exercise.
- Do not use the same student key on EC2.

### Configure a named CLI profile on the student computer

```bash
aws configure --profile dynamodb-student
```

Enter the lab user's Access Key ID and Secret Access Key when prompted, default region `ap-south-1`, and output format `json`. Keep the secret private.

Check the active identity and Region:

```bash
aws sts get-caller-identity --profile dynamodb-student
aws configure get region --profile dynamodb-student
```

Set convenience variables for this terminal:

```bash
export AWS_PROFILE=dynamodb-student
export AWS_REGION=ap-southeast-2
export TABLE_NAME=StudentsLab
```

Verify AWS CLI can contact DynamoDB:

```bash
aws dynamodb list-tables --region "$AWS_REGION"
```

> If `list-tables` is denied, the policy may not grant it. This is not required for CRUD; you can continue if the table commands work.

## Part 3 — Create a DynamoDB table

The table's partition key is `student_id` (String). There is no sort key in this beginner lab.

```bash
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=student_id,AttributeType=S \
  --key-schema AttributeName=student_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"
```

Wait until the table is active:

```bash
aws dynamodb wait table-exists \
  --table-name "$TABLE_NAME" \
  --region "$AWS_REGION"

aws dynamodb describe-table \
  --table-name "$TABLE_NAME" \
  --query 'Table.{Name:TableName,Status:TableStatus,Keys:KeySchema}' \
  --output table \
  --region "$AWS_REGION"
```

Expected: table status `ACTIVE`; partition key `student_id`.

## Part 4 — CRUD operations from the CLI

### C — Create (insert an item)

```bash
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item '{
    "student_id": {"S": "STU001"},
    "name": {"S": "Aarav Sharma"},
    "course": {"S": "AWS"},
    "score": {"N": "85"}
  }' \
  --region "$AWS_REGION"
```

Verify the item was inserted:

```bash
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{"student_id":{"S":"STU001"}}' \
  --consistent-read \
  --region "$AWS_REGION"
```

### R — Read one item

```bash
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{"student_id":{"S":"STU001"}}' \
  --region "$AWS_REGION"
```

Use `--projection-expression "student_id, #n, course"` to select fields (because `name` can be a reserved word, define `--expression-attribute-names '{"#n":"name"}'`).

### Add more records for query practice

```bash
aws dynamodb put-item --table-name "$TABLE_NAME" \
  --item '{"student_id":{"S":"STU002"},"name":{"S":"Diya Patel"},"course":{"S":"Linux"},"score":{"N":"91"}}' \
  --region "$AWS_REGION"

aws dynamodb put-item --table-name "$TABLE_NAME" \
  --item '{"student_id":{"S":"STU003"},"name":{"S":"Kabir Khan"},"course":{"S":"AWS"},"score":{"N":"78"}}' \
  --region "$AWS_REGION"
```

### U — Update an item

Update the score and add a city attribute:

```bash
aws dynamodb update-item \
  --table-name "$TABLE_NAME" \
  --key '{"student_id":{"S":"STU001"}}' \
  --update-expression 'SET #score = :score, city = :city' \
  --expression-attribute-names '{"#score":"score"}' \
  --expression-attribute-values '{":score":{"N":"95"},":city":{"S":"Mumbai"}}' \
  --return-values ALL_NEW \
  --region "$AWS_REGION"
```

### D — Delete an item

This deletes only item `STU003`, not the table:

```bash
aws dynamodb delete-item \
  --table-name "$TABLE_NAME" \
  --key '{"student_id":{"S":"STU003"}}' \
  --return-values ALL_OLD \
  --region "$AWS_REGION"
```

Confirm it is gone:

```bash
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{"student_id":{"S":"STU003"}}' \
  --region "$AWS_REGION"
```

Expected: empty response (no `Item` property).

## Part 5 — Query and scan

A **Query** requires a partition key value. With this table design, query one exact student ID:

```bash
aws dynamodb query \
  --table-name "$TABLE_NAME" \
  --key-condition-expression 'student_id = :id' \
  --expression-attribute-values '{":id":{"S":"STU001"}}' \
  --region "$AWS_REGION"
```

A **Scan** reads items across the table. It can be inefficient on large tables; use only for this small training table:

```bash
aws dynamodb scan \
  --table-name "$TABLE_NAME" \
  --projection-expression 'student_id, course, #n, #score' \
  --expression-attribute-names '{"#n":"name","#score":"score"}' \
  --region "$AWS_REGION"
```

## Part 6 — Create an EC2 role for DynamoDB access

The EC2 role is separate from the CLI user. EC2 must assume the role through an instance profile. Do **not** copy the IAM user's access keys onto EC2.

### Step 6.1 — Create the trust policy

Use `policies/ec2-trust-policy.json`. It trusts the EC2 service (`ec2.amazonaws.com`) to assume this role.

### Step 6.2 — Create the EC2 permissions policy

Copy `policies/ec2-dynamodb-policy-template.json` and replace:
- `REGION` with your chosen Region, e.g. `ap-south-1`
- `ACCOUNT_ID` with your 12-digit AWS account ID

This grants only `GetItem`, `PutItem`, `UpdateItem`, `DeleteItem`, `Query`, and `Scan` on the `StudentsLab` table. It deliberately does not grant table creation/deletion to the EC2 role.

### Step 6.3 — Create role and instance profile

You can do this in the AWS Console (IAM → Roles → Create role → AWS service → EC2) or use an administrator CLI session. Example CLI commands (run only from an authorized admin profile):

```bash
aws iam create-role \
  --role-name EC2DynamoDBLabRole \
  --assume-role-policy-document file://policies/ec2-trust-policy.json

aws iam put-role-policy \
  --role-name EC2DynamoDBLabRole \
  --policy-name EC2DynamoDBLabPolicy \
  --policy-document file://policies/ec2-dynamodb-policy-template.json
```

**Important:** Before running the second command, make sure the template placeholders have been replaced with real values. IAM role names and instance profile setup may require admin permissions.

Create the instance profile and associate the role:

```bash
aws iam create-instance-profile \
  --instance-profile-name EC2DynamoDBLabProfile

aws iam add-role-to-instance-profile \
  --instance-profile-name EC2DynamoDBLabProfile \
  --role-name EC2DynamoDBLabRole
```

Wait briefly for IAM propagation, then attach `EC2DynamoDBLabProfile` to your EC2 instance using the EC2 Console (Instance → Actions → Security → Modify IAM role), or the CLI:

```bash
aws ec2 associate-iam-instance-profile \
  --instance-profile Name=EC2DynamoDBLabProfile \
  --instance-id i-REPLACE_WITH_YOUR_INSTANCE_ID \
  --region "$AWS_REGION"
```

If the instance already has a profile, inspect and replace/modify it carefully rather than blindly associating another one.

### Step 6.4 — Connect to EC2 and verify role credentials

SSH into the instance. Ensure the instance has network connectivity to the DynamoDB public endpoint (normally outbound HTTPS/443; a private subnet may need a NAT gateway or a DynamoDB VPC endpoint).

Install/verify AWS CLI v2 as in Part 1, then run:

```bash
aws --version
aws sts get-caller-identity
```

The returned ARN should identify an assumed role similar to `assumed-role/EC2DynamoDBLabRole/...`. Do not run `aws configure` on this EC2 instance and do not place long-term access keys in `~/.aws/credentials`.

### Step 6.5 — Run CRUD from EC2

Set the Region and table name:

```bash
export AWS_REGION=ap-south-1
export TABLE_NAME=StudentsLab
```

Run an insert:

```bash
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item '{"student_id":{"S":"EC2-001"},"name":{"S":"EC2 Demo"},"course":{"S":"DevOps"}}' \
  --region "$AWS_REGION"
```

Read:

```bash
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{"student_id":{"S":"EC2-001"}}' \
  --region "$AWS_REGION"
```

Update:

```bash
aws dynamodb update-item \
  --table-name "$TABLE_NAME" \
  --key '{"student_id":{"S":"EC2-001"}}' \
  --update-expression 'SET course = :course' \
  --expression-attribute-values '{":course":{"S":"Cloud DevOps"}}' \
  --return-values ALL_NEW \
  --region "$AWS_REGION"
```

Delete:

```bash
aws dynamodb delete-item \
  --table-name "$TABLE_NAME" \
  --key '{"student_id":{"S":"EC2-001"}}' \
  --return-values ALL_OLD \
  --region "$AWS_REGION"
```

Expected: the role can perform item CRUD on `StudentsLab` but cannot create/delete tables or access other tables.

## Part 7 — Cleanup

First delete training items if you want to retain the table. To delete the table and avoid future table charges, run from the student CLI profile that has table deletion permission:

```bash
aws dynamodb delete-table \
  --table-name "$TABLE_NAME" \
  --region "$AWS_REGION"

aws dynamodb wait table-not-exists \
  --table-name "$TABLE_NAME" \
  --region "$AWS_REGION"
```

Also terminate the lab EC2 instance when finished. If you created a dedicated IAM access key, deactivate/delete it after the lab. If you created the role/profile for a temporary exercise, detach the profile from EC2 before deleting the instance profile and role. Delete the instance profile only after removing its role.

## Student checklist

- [ ] AWS CLI v2 installed and verified
- [ ] Dedicated CLI identity verified with `aws sts get-caller-identity`
- [ ] DynamoDB table created and active
- [ ] `put-item` and `get-item` tested
- [ ] `update-item` and `delete-item` tested
- [ ] `query` and `scan` compared
- [ ] EC2 role attached through instance profile
- [ ] EC2 identity shows the assumed role, not an IAM user
- [ ] EC2 can CRUD only the lab table
- [ ] Credentials not committed to Git
- [ ] Lab resources cleaned up

## Viva / interview questions

1. What is the difference between an IAM user and an IAM role?
2. Why should an EC2 instance use an IAM role instead of stored access keys?
3. What is a DynamoDB partition key?
4. What is the difference between `GetItem`, `Query`, and `Scan`?
5. Why is `PAY_PER_REQUEST` useful for a small lab?
6. Why does the EC2 role policy not include `CreateTable`?
7. What does `aws sts get-caller-identity` verify?
