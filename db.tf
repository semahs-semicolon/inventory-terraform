
resource "aws_instance" "database" {
    ami = "ami-09cb0f54fe24c54a6"
    instance_type = "t4g.micro"

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