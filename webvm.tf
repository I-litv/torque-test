resource "aws_security_group" "websg" {
    vpc_id = "${aws_vpc.vpc.id}"
    
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }    
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"        
        cidr_blocks = ["0.0.0.0/0"]
    }   
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }    

}


resource "aws_instance" "web" {
    depends_on = [aws_instance.db]
    ami = "ami-067f8db0a5c2309c0"
    instance_type = "t2.small"
    subnet_id = "${aws_subnet.public-sub-1.id}"
    vpc_security_group_ids = ["${aws_security_group.websg.id}"]
    key_name = "tko-cfox-key"
    user_data_replace_on_change = true
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
        Name = "Web-VM"
    }

}