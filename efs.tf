//Provider 
provider "aws" {
  region     = "ap-south-1"
  profile    = "default"
}


//Create Security Group
resource "aws_security_group" "rules" {
  name        = "allow_http_ssh"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = "vpc-504d5138"
  revoke_rules_on_delete = "true"
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress{
    description = "SSH for VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security_group"
  }
}

//Launch EC2 instance with same keypair and Security Group
resource "aws_instance" "AppInstance" {
  depends_on = [
    aws_security_group.rules,
  ]
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.rules.name}"]
  key_name = "keypair_docker_webserver"

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("./keypair_docker_webserver.pem")
    host        = aws_instance.AppInstance.public_ip
  }

  provisioner "remote-exec" {
    inline      = [
      "sudo yum install httpd php git -y " ,
      "sudo systemctl restart httpd" ,
      "sudo systemctl enable httpd"
    ]
  }
  tags = {
    name = "AppInstance"
  }
}

resource "null_resource" "nulllocal2"  { 
  provisioner "local-exec" {
	    command = "echo  ${aws_instance.AppInstance.public_ip} > publicip.txt"
 	}
}

output "myos_ip" {
    value = aws_instance.AppInstance.public_ip
}


//Security Group to allow NFS

resource "aws_security_group" "SG_EFS" {
  name        = "allow_nfs"
  description = "Allow NFS inbound traffic"
  vpc_id      = "vpc-504d5138"
  revoke_rules_on_delete = "true"
  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nfs_security_group"
  }
}

// Create EFS

resource "aws_efs_file_system" "EFS" {
creation_token = "elasticfilestorage"
  tags = {
    Name = "efs"
  }
  encrypted = "true"
}

// EFS mount target 

resource "aws_efs_mount_target" "EFS_mount" {
  depends_on = [
    aws_instance.AppInstance,
    aws_security_group.rules,
    aws_efs_file_system.EFS
  ]
  file_system_id = aws_efs_file_system.EFS.id
  subnet_id      = aws_instance.AppInstance.subnet_id
  security_groups = [ "${aws_security_group.SG_EFS.id}" ]
  
}

//copy code in /var/www/html

resource "null_resource" "Remote" {
  depends_on = [
    aws_efs_file_system.EFS,
  ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("./keypair_docker_webserver.pem")
    host     = aws_instance.AppInstance.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install amazon-efs-utils",
      "echo '${aws_efs_file_system.EFS.id}:/ /var/www/html efs _netdev,tls,iam 0 0' | sudo tee -a /etc/fstab",
      "sleep 2m" ,
      "sudo mount -t efs  '${aws_efs_file_system.EFS.id}':/ /var/www/html",
      "sudo rm -f /var/www/html/*",
      "df -hT",
      "sudo git clone https://github.com/kethavathsivanaik/terraform_task1.git  /var/www/html"
    ]
  }
}

output "efs_id" {
  value = aws_efs_file_system.EFS.id
}


//S3 bucket creation

resource "aws_s3_bucket" "s3buckettask1" {
    bucket = "s3buckettask1"
    acl    = "public-read"
    region = "ap-south-1"
    tags = {
      Name = "s3_bucket"
    }
}
locals {
    s3_origin_id = "s3_origin"
}

// S3 object upload

resource "aws_s3_bucket_object" "image_object" {
  depends_on = [
    aws_s3_bucket.s3buckettask1
  ]
  bucket = "s3buckettask1"
  acl    = "public-read"
  key    = "lamborgini.jpg"
  source = "./lambo.jpg"
}

resource "aws_s3_bucket_object" "image_object1" {
  depends_on = [
    aws_s3_bucket.s3buckettask1
  ]
  bucket = "s3buckettask1"
  acl    = "public-read"
  key    = "lamborgini1.jpg"
  source = "./lambo1.jpg"
}

resource "aws_s3_bucket_object" "image_object2" {
  depends_on = [
    aws_s3_bucket.s3buckettask1
  ]
  bucket = "s3buckettask1"
  acl    = "public-read"
  key    = "lamborgini2.jpg"
  source = "./lambo2.jpg"
}


resource "aws_s3_bucket_object" "image_object3" {
  depends_on = [
    aws_s3_bucket.s3buckettask1
  ]
  bucket = "s3buckettask1"
  acl    = "public-read"
  key    = "lamborgini3.jpg"
  source = "./lambo3.jpg"
}

//create a cloudfront using s3

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Access Identity"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
    aws_s3_bucket.s3buckettask1
  ]
  origin {
    domain_name = aws_s3_bucket.s3buckettask1.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "lamborgini.jpg"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}





//Update the cloudfront url in the code /var/www/html
resource "null_resource" "cloudfront_url"{
  depends_on = [aws_cloudfront_distribution.s3_distribution]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("./keypair_docker_webserver.pem")
    host     = aws_instance.AppInstance.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/__url__1/http:\\/\\/${aws_cloudfront_distribution.s3_distribution.domain_name}\\/${aws_s3_bucket_object.image_object.key}/' /var/www/html/index.html" ,
      "sudo sed -i 's/__url__2/http:\\/\\/${aws_cloudfront_distribution.s3_distribution.domain_name}\\/${aws_s3_bucket_object.image_object1.key}/' /var/www/html/index.html" ,
      "sudo sed -i 's/__url__3/http:\\/\\/${aws_cloudfront_distribution.s3_distribution.domain_name}\\/${aws_s3_bucket_object.image_object2.key}/' /var/www/html/index.html" ,
      "sudo sed -i 's/__url__4/http:\\/\\/${aws_cloudfront_distribution.s3_distribution.domain_name}\\/${aws_s3_bucket_object.image_object3.key}/' /var/www/html/index.html" 
    ]
  }
  
  // Adding image to website..
  provisioner "remote-exec" {
      inline = [
        "sudo su <<END",
        "echo \"<img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.image_object.key}' height='200' width='200'>\" >> /var/www/html/index.php",
        "END",
      ]
    }
}

output "cloudfront_url" {
  value       = "http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.image_object.key}"
  depends_on  = [aws_cloudfront_distribution.s3_distribution]
}

// launch the Application
resource "null_resource" "nulllocal1"  {

depends_on = [
    null_resource.cloudfront_url
  ]

provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.AppInstance.public_ip}"
  }
}



