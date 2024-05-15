# Kinetic Workspaces

Scaled on demand RStudio hosted on AWS ec2 instances.

## Description

Workspaces provide an easy-to-use method for Researchers to write analysis scripts against Kinetic data.  Using them, researchers can code in a familiar environment and interactively test their code against synthesized data.

When the researcher has completed development of their analysis code, they then submit it for running in the Kinetic data-enclave.

## Technical overview

The workspaces app is written in typescript and runs as a AWS lambda function with a very small React front-end.

Whenever a researcher attempts to load their workspace it loads a the small React screen that displays a spinner while it polls the lambda for status updates while it works to provision an ec2 instance.

The lambda reads the researcher's SSO cookie and [performs a request](front-desk/server/analysis.ts#5) using it to kinetic for the analysis details.

It then checks to see if it has an ec2 instance for the analysis in it's dynamodb database.  if not, it starts one up.

If there is an ec2 instance, it [provisions it](front-desk/server/provision.ts) if needed, then responds with the details and the small JS front-end replaces it's "Pending" spinner with an iframe that loads the ec2 instance using it's assigned hostname.

The JS front-end sends periodic heartbeat notices saying the researcher is still active.  Inactive ec2 instances that have not received heartbeat updates are terminated by a [housekeeping lambda call](deploy/front-desk.tf#95).

### Provisioning ec2 instances

Provisioning instances is a multi-step process.

 - The first step occurs when the lambda receives a request for an analysis that lacks an associated ec2 host.  It [then launches one](front-desk/server/aws.ts#42) and replies back that the host is "pending".  It takes approximate 10-20 seconds for the ec2 instance to have started up enough to have been assigned an ip4 public ip address.

- Once the lambda has a public ip address, we [assign it a random sub-domain](front-desk/server/aws.ts#90) on the workspaces.kinetic.openstax.org domain.  This allows us to later set cookies that the server can read.

- When the ec2 instance is fully booted, the lambda [finds or creates an EFS access point](front-desk/server/aws.ts#117) for it.  Note that the access point will exist and have previous work present if the researcher has used the analysis in the past.

- The lambda then [ssh's into the ec2 instance](front-desk/server/provision.ts), mounts the access point, and checks if it has previous work present or was empty.  If empty it downloads a blank project and pre-fills various bits of information, such as the API key to access the test data and git repo url.

 - After all the above steps are complete, the lambda then sets a [specially crafted cookie](front-desk/server/authentication.ts#24) with the newly created username.

- The [iframe src](front-desk/editor.tsx#60) is then is set to the new sub-domain and RStudio authenticates using the cookie.

## Synthetic Data

When users are testing their code inside RStudio and call the `fetch_kinetic_responses` api method, the R library requests responses from the kinetic `/api/v1/researcher/analysis/<id>` endpoint using the API key that the analysis was provisioned with by storing it in the `~/.Renviron` file.   The endpoint also accepts an enclave api key that is only used inside the enclave and not from RStudio.  If that key is present, real responses are returned, otherwise sythetic data is provided.

* Synthetic data is pre-generated using scripts in the `synthetic-data` directory of this repo.  The [run](synthetic-data/run) script accepts a single command line argument which is a path to a real dataset.
  * Some studies have a cleaning script that downloads and cleans the data.  See [synthetic-data/science-knowledge.r](synthetic-data/science-knowledge.r) as an example.  It can be ran as `R -f science-knowledge.r`
* It boots up a docker environment and runs `generate.py` inside it.
* generate.py is a work in progress, some of the [plugins](synthetic-data/generate.py#L35) work only with various sets and may need to be modified in order to successfully generate for each set.
* Once a dataset is generated, it can be uploaded in the kinetic "Manage Workspaces" admin UI for each study.

RStudio will then download these response files when `fetch_kinetic_responses` is called.  If a study does not have a pre-generated dataset, then Kinetic will [generate random data](https://github.com/openstax/kinetic/blob/main/backend/app/services/qualtrics_test_data.rb) and return that.  Random data is non-optimal; the distributions will be random and not match the real study.

### RStudio modifications

- We set the RStudio secret to a known value which allows our code to generate a cookie and stop RStudio from showing it's login.
- Various parts of the RStudio user-interface [are patched](deploy/configs/install_rstudio#L21-23) to add scripts.
- Those [scripts](deploy/assets/) add the submit code button and notify the front-desk when RStudio is inactive.
- The Kinetic API has two tutorial files.
  - One is a general tutorial about using Kinetic
  - The other is a small JS wrapper.  The JS code detects whhich analysis is running and requests HTML info files from Kinetic to display inside an iframe.

### Running code in enclave

- When the submit analysis button is clicked, the front-desk lambda requests begins invocation of a [state machine](deploy/stats.tf)

The state machine:
- Creates a Z archive of the user's home directory
- The [state machine lambda](enclave/run-ec2-task.ts) starts a ec2 instance using a [custom image](deploy/enclave_image.tf).  The lambda sets the "UserData" of the instance to custom code that performs the docker build, pushes to aws container registry, then terminates the ec2.
  - When this becomes operational, it's likely this will be done on a dedicated ec2 instance.  We're using ephemeral servers for cost savings since runs are very infrequent.
- **TODO**: Perform both automated and manual checks on the code, and only upload to container registry when passing.
- The state machine then does a nearly identical process, the lambda starts a new ec2 instance with UserData set to code that downloads the docker image and runs it.
- **TODO:** run security audit on the [docker run command](enclave/enclave-run.ts) to restrict network access and set any other security flags possible.
- All data in the "data" directory is zipped up and stored on S3.  A temporary url is emailed to the user to download the data.
- **TODO**: Perform both automated and manual checks on the data and only send url when it's deemed safe
