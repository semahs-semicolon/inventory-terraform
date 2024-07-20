

resource "aws_ssm_parameter" "database_password" {
  type = "SecureString"
  name = "database_password"
  value = "e"
}

resource "aws_instance" "database" {
    ami = "ami-09cb0f54fe24c54a6"
    instance_type = "t4g.nano"

    user_data = <<-EOL
        #!/bin/bash -xe
        apt update
        apt install postgresql --yes
        EOL
    // will take care of it manually
  
    tags = {
        Name = "Database"
    }
    
}