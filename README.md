# Kinetic Workspaces

Scaled on demand RStudio hosted on AWS ec2 instances.

## Description

Workspaces provide an easy-to-use method for Researcehrs to write analysis scripts against Kinetic data.  Using them, researchers can code in a familiar environment and interactively test their code against synthesized data.

When the researcher has completed development of their analysis code, they then submit it for running in the Kinetic data-enclave.

## Technical overview

The workspaces app is written in typescript and runs as a AWS lambda function with a very small React front-end.

Whenever a researcher attempts to load their workspace it loads a the small React screen that displays a spinner while it polls the lambda for status updates and it works to provision an ec2 instance.

The lambda reads the researcher's SSO cookie and [performs a request](front-desk/server/analysis.ts:5) using it to kinetic for the analysis details.

It then checks to see if it has an ec2 instance for the analysis in it's dynamodb database.  if not, it starts one up.

If there is an ec2 instance, it provisions it if needed, then responds with the details and the small JS frontend replaces it's "Pending" spinner with an iframe that loads the ec2 instance using it's assigned hostname.

The JS front-end sends periodic heartbeat notices saying the researcher is still active.  Inactive ec2 instances that have not recieved heartbeat updates are terminated by a [houskeeping lambda call](deploy/front-desk.tf:95).

### Provisioning ec2 instances

Provisioning instances is a multi-step process.

 - The first step occurs when the lambda recieves a request for an anlysis that lacks an associated ec2 host.  It [then launches one](front-desk/server/aws.ts:42) and replies back that the host is "pending".  It takes approximate 10-20 seconds for the ec2 instance to have started up enough to have been assigned an ip4 public ip address.

- Once the lambda has a public ip address, we [assign it a random subdomain](front-desk/server/aws.ts:90) on the workspaces.kinetic.openstax.org domain.  This allows us to later set cookies that the server can read.

- When the ec2 instance is fully booted, the lambda [finds or creates an EFS access point](front-desk/server/aws.ts:117) for it.  Note that the access point will exist and have previous work present if the researcher has used the anlysis in the past.

- The lambda then [ssh's into the ec2 instance](front-desk/server/profile.ts), mounts the access point, and checks if it has previous work present or was empty.  If empty it downloads a blank project and pre-fills various bits of information, such as the API key to access the test data and git repo url.

 - After all the above steps are complete, the lambda then sets a [specially crafted cookie](front-desk/server/authentication:24) with the newly created username.

- The [iframe src](front-desk/editor.tsx:60) is then is set to the new subdomain and rstudio authenticates using the cookie.
