# Security Group
variable "ingressports" {
  type    = list(number)
  default = [8080, 22, 443, 0]
}

resource "aws_security_group" "jenkins-sg" {
  name        = "Allow web traffic"
  description = "http, ssh, https"
  dynamic "ingress" {
    for_each = var.ingressports
    content {
      protocol    = "tcp"
      from_port   = ingress.value
      to_port     = ingress.value
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name"      = "Jenkins-sg"
    "Terraform" = "true"
  }
}

# EC2 for Jenkins
resource "aws_instance" "jenkins" {
  ami             = "ami-069d73f3235b535bd"
  instance_type   = "t2.medium"
  security_groups = [aws_security_group.jenkins-sg.name]
  key_name        = "jenkins23"
  provisioner "remote-exec" {
    inline = [
        "sudo yum update –y",
        "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
        "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key",
        "sudo yum upgrade",
        "sudo dnf install java-11-amazon-corretto -y",
        "sudo yum install jenkins -y",
        "sudo systemctl enable jenkins",
        "sudo systemctl start jenkins"
    ]
  }
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = data.aws_ssm_parameter.jenkins_pem.value
  }
  tags = {
    "Name" = "Jenkins"
  }
}


# Pem file connecting
data "aws_ssm_parameter" "jenkins_pem" {
  name = "/secure/inf/jenkins_pem"
}

# Setup s3 for static site hosting/artifacts
resource "aws_s3_bucket" "jenkins_artifacts" {
  bucket = "jennkins-demo-pipeline-2023-riley"
}

resource "aws_s3_bucket_website_configuration" "jenkins_www_config" {
  bucket = aws_s3_bucket.jenkins_artifacts.id
  index_document {
    suffix = "index.html"
  }
}

# Make bucket accessable to web
resource "aws_s3_bucket_policy" "www_policy" {
  bucket = aws_s3_bucket.jenkins_artifacts.id
  policy = data.aws_iam_policy_document.allow_www.json
}

data "aws_iam_policy_document" "allow_www" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject",
    ]
    effect = "Allow"
    resources = [
      aws_s3_bucket.jenkins_artifacts.arn,
      "${aws_s3_bucket.jenkins_artifacts.arn}/*",
    ]
  }
}
