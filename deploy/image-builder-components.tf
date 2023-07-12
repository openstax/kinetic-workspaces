resource "aws_imagebuilder_component" "kinetic_workspaces_install_r" {
  name     = "kinetic${local.env_dash}-workspaces-install-r"
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
        name      = "install_r"
        onFailure = "Abort"
        inputs = {
          commands = [
            "export DEBIAN_FRONTEND=noninteractive TZ=America/Chicago",
            "sudo -E bash /tmp/install_r_and_pkgs ${aws_s3_bucket.kinetic_workspaces_conf_files.id}",
          ]
        }
      }]
    }]
  })
}

resource "aws_imagebuilder_component" "kinetic_workspaces_base_config" {
  name     = "kinetic${local.env_dash}-workspaces-base-config"
  platform = "Linux"
  version  = "0.0.1"

  depends_on = [

  ]

  data = yamlencode({
    schemaVersion = 1.0
    phases = [{
      name = "build"
      steps = [
        {
          action    = "ExecuteBash"
          name      = "install_base_packages"
          onFailure = "Abort"
          inputs = {
            commands = [
              "sudo apt-get update",
              "DEBIAN_FRONTEND=noninteractive TZ=America/Chicago sudo -E apt-get install -y curl wget git vim awscli",
            ]
          }
        },
        {
          action    = "S3Download"
          name      = "download_conf_files"
          onFailure = "Abort"
          inputs = [{
            source      = "s3://${aws_s3_bucket.kinetic_workspaces_conf_files.id}/configs/*",
            destination = "/tmp/",
          }]
        }
      ]
    }]
  })
}

resource "aws_imagebuilder_component" "kinetic_install_docker_build" {
  name     = "kinetic${local.env_dash}-install-docker-build"
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
            "export DEBIAN_FRONTEND=noninteractive TZ=America/Chicago",
            "ls /tmp",
            "sudo -E bash /tmp/install_ruby",
            "sudo -E apt-get install -y ca-certificates gnupg",
            "sudo install -m 0755 -d /etc/apt/keyrings",
            "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
            "sudo chmod a+r /etc/apt/keyrings/docker.gpg",
            "echo deb [signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
            "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -",
            "sudo -E apt-get update",
            "sudo -E apt-get install -y nodejs zstd zip docker-ce docker-buildx-plugin docker-compose-plugin",
            "sudo -E npm install -g dockerode @aws-sdk/client-ecr @aws-sdk/client-ec2 @aws-sdk/client-s3 @aws-sdk/client-sfn",
          ]
        }
      }]
    }]
  })
}

resource "aws_imagebuilder_component" "kinetic_workspaces_editor" {
  name     = "kinetic${local.env_dash}-workspaces-editor"
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
        name      = "workspaces_rstudio_editor"
        onFailure = "Abort"
        inputs = {
          commands = [
            "export DEBIAN_FRONTEND=noninteractive",
            "sudo apt-get install -y gdebi-core ruby-full build-essential binutils nginx-light certbot python3-certbot-dns-route53",
            "sudo gem install aws-sdk-s3",
            "cd /tmp && git clone https://github.com/aws/efs-utils",
            "cd /tmp/efs-utils && ./build-deb.sh && sudo apt-get -y install ./build/amazon-efs-utils*deb",
            "sudo -E bash /tmp/install_rstudio ${local.domain_name} ${random_id.rstudio_cookie_key.hex}",
            "ruby /tmp/provision-letsencrypt ${local.domain_name} ${aws_s3_bucket.kinetic_workspaces_conf_files.id}",
            "sudo aws s3 cp s3://${aws_s3_bucket.kinetic_workspaces_conf_files.id}/configs/nginx-proxy.conf /etc/nginx/sites-enabled/default",
            "sudo sudo apt-get clean",
          ]
        }
      }]
    }]
  })
}
