resource "aws_imagebuilder_component" "kinetic_workspaces_install_r_and_pkgs" {
  name     = "kinetic_workspaces_install_r_and_pkgs"
  platform = "Linux"
  version  = "0.0.1"

  depends_on = [

  ]
  data = yamlencode({
    schemaVersion = 1.0
    phases = [{
      name = "build"
      steps = [{
        action    = "ExecuteBash"
        name      = "download_and_install_kinetic_workspaces"
        onFailure = "Abort"
        inputs = {
          commands = [
            "export DEBIAN_FRONTEND=noninteractive",
            "sudo bash /tmp/install_r_and_pkgs ${aws_s3_bucket.kinetic_workspaces_conf_files.id}",
          ]
        }
      }]
    }]
  })
}

resource "aws_imagebuilder_component" "kinetic_workspaces_config_files" {
  name     = "kinetic_workspaces_config_files"
  platform = "Linux"
  version  = "0.0.1"

  depends_on = [

  ]
  data = yamlencode({
    schemaVersion = 1.0
    phases = [{
      name = "build"
      steps = [{
        action    = "S3Download"
        name      = "download_and_install_conf_files"
        onFailure = "Abort"
        inputs = [{
          source      = "s3://${aws_s3_bucket.kinetic_workspaces_conf_files.id}/configs/*",
          destination = "/tmp/",
        }]
      }]
    }]
  })
}

resource "aws_imagebuilder_component" "kinetic_install_docker_build" {
  name     = "kinetic_install_docker_build"
  platform = "Linux"
  version  = "1.0.0"

  data = yamlencode({
    schemaVersion = 1.0
    phases = [{
      name = "build"
      steps = [{
        action    = "ExecuteBash"
        name      = "run_install_docker_build"
        onFailure = "Abort"
        inputs = {
          commands = [
            "export DEBIAN_FRONTEND=noninteractive",
            "ls /tmp",
            "sudo bash /tmp/install_ruby",
            "sudo apt-get install -y ca-certificates curl gnupg",
            "sudo install -m 0755 -d /etc/apt/keyrings",
            "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
            "sudo chmod a+r /etc/apt/keyrings/docker.gpg",
            "echo deb [signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bullseye stable | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
            "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -",
            "sudo apt-get update",
            "sudo apt-get install -y nodejs docker-ce docker-buildx-plugin docker-compose-plugin",
            "sudo npm install -g node-docker-api @aws-sdk/client-ec2 @aws-sdk/client-s3 @aws-sdk/client-sfn",
          ]
        }
      }]
    }]
  })
}

resource "aws_imagebuilder_component" "ec2_kinetic_workspaces" {
  name     = "configure_ec2_kinetic_workspaces"
  platform = "Linux"
  version  = "1.0.0"

  depends_on = [
    aws_s3_object.kinetic_workspaces_conf_files["nginx-proxy.conf"],
    aws_s3_object.kinetic_workspaces_conf_files["provision-letsencrypt"],
  ]

  # ExecuteBash https://docs.aws.amazon.com/imagebuilder/latest/userguide/toe-action-modules.html#action-modules-executebash
  data = yamlencode({
    schemaVersion = 1.0
    phases = [{
      name = "build"
      steps = [{
        action    = "ExecuteBash"
        name      = "download_and_install_kinetic_workspaces"
        onFailure = "Abort"
        inputs = {
          commands = [
            "export DEBIAN_FRONTEND=noninteractive",
            "sudo apt-get update",
            "sudo apt-get install -y git gdebi-core ruby-full build-essential binutils nginx-light certbot python3-certbot-dns-route53",
            "sudo gem install aws-sdk-s3",
            "sudo wget --no-verbose -O /tmp/ssm.deb https://s3.${var.aws_region}.amazonaws.com/amazon-ssm-${var.aws_region}/latest/debian_amd64/amazon-ssm-agent.deb",
            "sudo dpkg -i /tmp/ssm.deb",
            "cd /tmp && git clone https://github.com/aws/efs-utils",
            "cd /tmp/efs-utils && ./build-deb.sh && sudo apt-get -y install ./build/amazon-efs-utils*deb",
            "sudo bash /tmp/install_rstudio ${local.domain_name} ${random_id.rstudio_cookie_key.hex}",
            "ruby /tmp/provision-letsencrypt ${local.domain_name} ${aws_s3_bucket.kinetic_workspaces_conf_files.id}",
            "sudo aws s3 cp s3://${aws_s3_bucket.kinetic_workspaces_conf_files.id}/configs/nginx-proxy.conf /etc/nginx/sites-enabled/default",
            "sudo sudo apt-get clean",
          ]
        }
      }]
    }]
  })
}
