provider "aws" {
  region = "ap-south-1"
}

# Step 1-->Create Ec2 ins. with name DB Server and output the private IP
resource "aws_instance" "myec2db" {
  instance_type = "t2.micro"
  ami           = "ami-052cef05d01020f1d"

  tags = {
    Name = "DB Server"
  }
}

output "dbserver_privateip" {
  value = aws_instance.myec2db.private_ip
}

#Create EC2 ins. with name Web Server , ensure it has a fixed public IP
resource "aws_instance" "myec2web" {
  instance_type   = "t2.micro"
  ami             = "ami-052cef05d01020f1d"
  key_name = aws_key_pair.loginkey.key_name #ec2 ins which created will use this key pair.

  security_groups = [aws_security_group.sg_for_webserver.name] #name - (Optional, Forces new resource) Name of the security group. If omitted, Terraform will assign a random, unique name.
  //Step 4-->Run provided script on the web server,using user_data, once ec2 ins. is started , its next thing to run.(Called as Bootstrap script)
 user_data = file("server-script.sh") //file function reads sontents of the script and then pass it to user data
 #Might configure ins. with ansible,chef etc using terraform, user data if fails, tere is no sorf of recovery process as it is not going to try again, it will just fail. Ins will stay up,script won't have run
 /*
  user_data       = <<EOF
#!/bin/bash
sudo yum update
sudo yum install -y httpd
sudo systemctl start httpd
sudo systemctl enable httpd
echo "<h1>Hello from Terraform</h1>" | sudo tee /var/www/html/index.html"
EOF */

  tags = {
    Name = "Web Server"
  }
}


#Step 2--> Create EC2 ins. with name Web Server , ensure it has a fixed public IP
resource "aws_eip" "webservereip" {
  instance = aws_instance.myec2web.id // attaching EIP to ec2 web server
}


output "publicIP_webserver" {
 value = aws_eip.webservereip.public_ip
  
}

variable "ingress_rule_WebServer" {
  type    = list(number)
  default = [80, 443,22]
}

variable "egress_rule_webServer" {
  type    = list(number)
  default = [0]
}

#Step 3-->Create SG for web server , open port 80 and 443(HTTP and HTTPS)
resource "aws_security_group" "sg_for_webserver" {
  name        = "allow_HTTP_And_HTTPS"
  description = "SG for Web Server"

  dynamic "ingress" {
    iterator = port                       // creating iterator named port, sets the name of a temporary variable that represents the current element of the complex value.
    for_each = var.ingress_rule_WebServer // itetating via each items in the list, 1st time it will go through 80 and second time 443
    content {
      description = "HTTP and HTTPS from anywhere"
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]}
    }
  }
  dynamic "egress" {
    iterator = port                      // creating iterator named port
    for_each = var.egress_rule_webServer // itetating via each items in the list, 1st time it will go through 80 and second time 443
    content {
      description = "0 from everywhere"
      from_port   = port.value
      to_port     = port.value
      protocol    = "-1" # -1 for all protocall
      cidr_blocks = ["0.0.0.0/0"]
      # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]}
    }
  }

  tags = {
    Name = "SG for web server"
  }
}


resource "aws_key_pair" "loginkey" {
  key_name   = "loginkey_LinuxInstance"
  public_key = file("mykey.txt")
}


#Ec2 supports .ppk file format, need to convert .pem to ppk if required