
resource "aws_instance" "vmweb" {
  ami = "ami-067f8db0a5c2309c0"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.websg.id ]
  user_data = <<EOF
        #!/bin/bash
        apt-get update -y
        apt-get install default-jdk -y
        apt-get install tomcat8 -y
        apt-get install tomcat8-admin -y
        DB_PASS=Password1
        DB_USER=root
        DB_NAME=test
        DB_HOSTNAME="${aws_instance.db.private_ip}"
        mkdir /home/artifacts
        cd /home/artifacts || exit
        git clone https://github.com/QualiTorque/sample_java_spring_source.git
        mkdir /home/user/.config/torque-java-spring-sample -p
        jdbc_url=jdbc:mysql://$DB_HOSTNAME/$DB_NAME
        bash -c "cat >> /home/user/.config/torque-java-spring-sample/app.properties" <<EOL
        # Dadabase connection settings:
        jdbc.url=$jdbc_url
        jdbc.username=$DB_USER
        jdbc.password=$DB_PASS
        EOL
        #remove the tomcat default ROOT web application
        rm -rf /var/lib/tomcat8/webapps/ROOT
        # deploy the application as the ROOT web application
        cp sample_java_spring_source/artifacts/torque-java-spring-sample-1.0.0-BUILD-SNAPSHOT.war /var/lib/tomcat8/webapps/ROOT.war
        systemctl start tomcat8
        EOF
    tags = {
      Name = "web"
    }
}

resource "aws_instance" "vmdb" {
  ami = "ami-067f8db0a5c2309c0"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.websg.id ]
  user_data = <<EOF
        #!/bin/bash
        apt-get update -y
        DB_PASS=Password1
        DB_USER=root
        DB_NAME=test
        # Preparing MYSQL for silent installation
        export DEBIAN_FRONTEND="noninteractive"
        echo "mysql-server mysql-server/root_password password $DB_PASS" | debconf-set-selections
        echo "mysql-server mysql-server/root_password_again password $DB_PASS" | debconf-set-selections
        # Installing MYSQL
        apt-get install mysql-server -y
        #apt-get install mysql-client -y
        # Setting up local permission file
        mkdir /home/pk;
        bash -c "cat >> /home/pk/my.cnf" <<EOL
        [client]
        ## for local server use localhost
        host=localhost
        user=$DB_USER
        password=$DB_PASS
        [mysql]
        pager=/usr/bin/less
        EOL
        # Creating database
        mysql --defaults-extra-file=/home/pk/my.cnf << EOL
        CREATE DATABASE $DB_NAME;
        EOL
        # Configuring Remote Connection Access: updating sql config to not bind to a specific address
        sed -i 's/bind-address/#bind-address/g' /etc/mysql/mysql.conf.d/mysqld.cnf
        # granting db access
        mysql --defaults-extra-file=/home/pk/my.cnf << EOL
        GRANT ALL ON *.* TO $DB_USER@'%' IDENTIFIED BY "$DB_PASS";
        EOL
        mysql --defaults-extra-file=/home/pk/my.cnf -e "FLUSH PRIVILEGES;"
        systemctl restart mysql.service
        EOF
    tags = {
      Name = "db"
    }
} 
resource "aws_security_group" "websg" {
  name = "web-sg01"
  ingress {
    protocol = "tcp"
    from_port = 8080
    to_port = 8080
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}
output "instance_ips" {
  value = aws_instance.vmweb.public_ip
}  
output "instance_ips2" {
     value = aws_instance.vmdb.public_ip
}
 







































/*
resource "aws_db_instance" "default" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name                 = "mydb"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}
 
 resource "aws_instance" "app_server" {
  ami           = "ami-0d9858aa3c6322f73"
  instance_type = "t2.micro"
  key_name= "aws_key"
    vpc_security_group_ids = [aws_security_group.websg.id]

  provisioner "remote-exec" {
    inline = [
      "touch hello.txt",
      "echo helloworld remote provisioner >> hello.txt",
    ]
  }
  connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file("/home/rahul/Jhooq/keys/aws/aws_key")
      timeout     = "4m"
   }

  tags = {
    Name = "ExampleAppServerInstance"
  }
  
}
resource "aws_security_group" "websg" {
  name = "web-sg01"
  ingress {
    protocol = "tcp"
    from_port = 8080
    to_port = 8080
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

 resource "aws_subnet" "publicsubnets" {    # Creating Public Subnets
   vpc_id =  "vpc-068272a401b74bb84"
   cidr_block = "${var.public_subnets}"        # CIDR block of public subnets
 } 

output "instance_ips" {
    value = aws_instance.app_server.public_ip
    }



 resource "aws_internet_gateway" "IGW" {    # Creating Internet Gateway
    vpc_id =  aws_vpc.Main.id               # vpc_id will be generated after we create VPC
 }
               
  # Creating Private Subnets
 resource "aws_subnet" "privatesubnets" {
   vpc_id =  aws_vpc.Main.id
   cidr_block = "${var.private_subnets}"          # CIDR block of private subnets
 }
 resource "aws_route_table" "PublicRT" {    # Creating RT for Public Subnet
    vpc_id =  aws_vpc.Main.id
         route {
    cidr_block = "0.0.0.0/0"               # Traffic from Public Subnet reaches Internet via Internet Gateway
    gateway_id = aws_internet_gateway.IGW.id
     }
 }
 resource "aws_route_table" "PrivateRT" {    # Creating RT for Private Subnet
   vpc_id = aws_vpc.Main.id
   route {
   cidr_block = "0.0.0.0/0"             # Traffic from Private Subnet reaches Internet via NAT Gateway
   nat_gateway_id = aws_nat_gateway.NATgw.id
   }
 }
 resource "aws_route_table_association" "PublicRTassociation" {
    subnet_id = aws_subnet.publicsubnets.id
    route_table_id = aws_route_table.PublicRT.id
 }
 resource "aws_route_table_association" "PrivateRTassociation" {
    subnet_id = aws_subnet.privatesubnets.id
    route_table_id = aws_route_table.PrivateRT.id
 }
 resource "aws_eip" "nateIP" {
   vpc   = true
 }
 resource "aws_nat_gateway" "NATgw" {
   allocation_id = aws_eip.nateIP.id
   subnet_id = aws_subnet.publicsubnets.id
 }
*/