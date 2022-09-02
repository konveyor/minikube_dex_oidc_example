# Minikube + Dex example
This example will walk through setting up [minikube](https://minikube.sigs.k8s.io/docs/) with a [Kubernetes OpenID Connect token authenticator plugin](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens) via [Dex](https://dexidp.io/) + [GitHub](https://dexidp.io/docs/connectors/github/).  We will be able to authenticate via GitHub, obtaining a JWT token from Dex that we can subsequently use against the Kubernetes API Server to prove who we are.

The work in this repo is heavily based on the following sources:
*  Kubernetes Authentication Through Dex: https://dexidp.io/docs/kubernetes/
*  https://github.com/Spantree/dex-demo-github

Environments tested
* Linux with minikube --provider=podman
* Mac M1 with minikube --provider=docker 
  * Have some hacks in place as I didn't see a clean way to get NodePort to be accessible on Mac from minikube, related to https://github.com/kubernetes/minikube/issues/11193
  
## Goals
* Deploy minikube with [Dex Authenticating through GitHub](https://dexidp.io/docs/connectors/github/) 
* Deploy a [sample app originally from the Dex GitHub Repo](https://github.com/dexidp/dex/tree/master/examples/example-app) leveraging Dex to obtain a JWT token
* Decode the JWT to understand what is in the JWT 
* Understand how the Kubernetes API Server uses the JWT for 'authentication'
* Setup a small RBAC example in the k8s cluster to demonstrate the full workflow of Authentication + Authorization
 

# Prerequisites
## Create a file SECRET.source_me to hold environment variables
* `cp example.SECRET.source_me SECRET.source_me` 
  * We will use this file `SECRET.source_me` as the place to customize and store several environment variables.
  * NOTE:  This file will contain sensitive information, it is configured in `.gitignore` to be ignored.  Take care to not commit to source control.
  * Environment Variables
     * export MY_MINIKUBE_IP="192.168.49.2"
       * We need this value to match the IP address of your minikube host.  
         * To obtain this, launch your minikube cluster and find what `minikube ip` says. 
         * This is a bit of a chicken/egg problem.  We need the value prior to launching minikube, I don't know how to determine this ahead of time, so for now let's launch the cluster, get the value, and stop/delete the cluster.  The value appears to be reused between runs.
     * export MY_USERNAME="my_email_in_github@example.com"
       * We will confirm the value later when we look at the JWT and decode it.
     * export GITHUB_CLIENT_ID="ClientId"
       * We will need to obtain this from GitHub, see below
     * export GITHUB_CLIENT_SECRET="ClientSecret"
       * We will need to obtain this from GitHub, see below
     * export DEX_TOKEN=""
       * After we have Dex running, we will use a sample app to obtain a JWT token and store it here.
## Create an OAuth application GitHub
We will assume our Dex service will be reachable on `dex.example.com:32000`, we will add entries in the file `/etc/hosts` on our local computer and in the minikube configuration to allow this to work for our example.

Steps:
1. Visit:  https://github.com/organizations/konveyor/settings/applications
   * Homepage URL:  https://dex.example.com:32000
   * Authorization Callback URL:  https://dex.example.com:32000/callback
   * Save the new app
2. Create a new Client Secret
3. Record the values of ClientID and Client Secret in `SECRET.source_me`
   
        export GITHUB_CLIENT_ID="ClientId"
        export GITHUB_CLIENT_SECRET="ClientSecret"

# Example: Minikube + Dex 
## Background
 * T.B.D Add an overview diagram explaining the workflow of this example
 * Diagram #1 simpler picture of k8s + Dex + GitHub 
 * Diagram #2 expand on Diagram #1 and show how this is configured with minikube in the mix to show more info of nature of networking nuances
## Steps to bring up k8s cluster with OIDC handled via Dex
1. `source SECRET.source_me`
   * We will need environment variables from this file defined in the executing environment for some of the below scripts.

2. Run `gencert.sh` 
   * Will create local certs for Dex
   * Copied from: https://github.com/dexidp/dex/blob/master/examples/k8s/gencert.sh 
     * We ran into a few issues with Chrome not liking SHA1 signed certificates so we tweaked the script to use the SHA256 'Signature Algorithm' 
3. Trust these certs in your web browser
   * Note: For MAC, you can run the script:  `trust_ca_pem.sh` to add these to `/Library/Keychains/System.keychain` 
   * For Linux, you are likely fine to just accept the certs in the browser at time of accessing the URL
4. Run `VM_PROVIDER=podman launch_minikube.sh` 
   * If you need to change to docker set `VM_PROVIDER=docker`
   * Will bring up the k8s cluster via minikube with OIDC configured via Dex
     * copy the generated certificates to `~/.minikube/files/var/lib/minikube/certs/` which gets included in the minikube host.
     * configure the k8s api-server with OIDC
5. Run `dex_install.sh` to install Dex into the k8s cluster and created needed secrets for the GitHub OAuth2 application
   * Dex will be configured to run with a NodePort Service of 32000
   * Note:  This assumes you have previously sourced `SECRET.source_me`
6. MAC Only - Port forward the Dex port 5556 to localhost:32000
   * This is a workaround I needed to do on Mac as I couldn't access the NodePort service with minikube on Mac.  You do NOT need to do this if running on Linux
    * Run: `port_forward_dex.sh`
      * Leave this command running throughout the length of the example
    * Note:  We still do leverage the NodePort Service inside the cluster, this is how the k8s-api-server accesses Dex
      * The k8s-api-server is told to contact Dex for oidc-issuer via the minikube parameter:
        * `--extra-config=apiserver.oidc-issuer-url=https://dex.example.com:32000` from `launch_minikube.sh`
      * Minikube host has it's `/etc/hosts` created at time of launching `launch_minikube.sh`
7. Edit my `/etc/hosts` on the host you will run your web browser on to add an entry of:
   * MAC:  `127.0.0.1 dex.example.com`
      * We will run a port forward on localhost for port local port 32000 to the dex pod
   * Linux: `192.168.2.49 dex.example.com`
      * We will leverage the configured NodePort on the k8s server and use the value of `minikube ip`

## Run a sample application that will authenticate via Dex
We will deploy a sample application now to leverage Dex, it will login via a GitHub account and then give us a simple webpage that displays the tokens.  We will re-use this same 'ID Token' against the k8s-api-server later.

Steps:
1. Run the example:  `run_dex_example.sh`
2. Login to the printed URL of the example and select GitHub
   * Note:  You will likely need to ensure your web browser has trusted the certificates we generated earlier.
3. Confirm you see 2 tokens displayed on the page, an 'ID Token' and a 'ACCESS Token'.
   * The 'ID Token' is the token we are interested in and what we will use.
4. Edit your `SECRET.source_me` and update the value of `DEX_TOKEN` to match what your 'ID Token'.  
   * Note:  This token is a Javascript Web Token or JWT
5. Let's decode the JWT
   1. Confirm the user info in the JWT token matches the `email` you expected from logging into GitHub
   2. Run: `decode_jwt.sh`

            $ ./decode_jwt.sh  
            Decoding:
            eyJhbGciOiJSUzI1NiIsImtpZCI6IjkzYTU2OGRhNjViM2E2N2Q5YmQxNTBjYThkNGYxNDg4MWY1NmMyZTQifQ.eyJpc3MiOiJodHRwczovL2RleC5leGFtcGxlLmNvbTozMjAwMCIsInN1YiI6IkNnWXlNRFk0TnSAMPLEJtZHBkR2gxWWciLCJhdWQiOiJleGFtcGxlLWFwcCIsImV4cCI6MTY1MjUzNTAzNywiaWF0IjoxNjUyNDQ4NjM3LCJhdF9oYXNoIjoibzZtNVgtemhvZE9BSlFZeWozME9tZyIsImNfaGFzaCI6IkoxFOOZpZjNtZ2ciLCJlbWFpbCI6ImptYXR0aGV3QHJlZGhhdC5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwibmFtZSI6IkpvaG4gTWF0dGhld3MiLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJqd21hdHRoZXdzIn0.QwZJjgKPJNl41tooP9BHXf6pHfKpMtU8eokutvQVUyVY_IKfbHC0zOggp4UbcvRAUpmUsofFk75RUfeKRRLeK6X7sGoSihoQjQk_D8tgSj3YRWIkYAjFkZ75uHUvgCbYbwvPMfOKquJBAR3S55Bt_CBedPCOP3e_dFLRcflZzt-vO8EkG2pBLDCewdTMRfMpvvF0PktHkPxUs5egiwDWXNqWnuM1XJGRVpnXCsUWqyM4xBp9HMgSyBW2LTDzPYclnyaYSZtcUHr_yAxqLX1C7WdPH_LR2_j5DzVlSPAxvMDUBbItilQ-mPXqQguxpheZtHUUBf26wADCQ

            Decoded JWT text:
            {
            "iss": "https://dex.example.com:32000",
            "sub": "CgYyMDY4NzUSBmdpdGh1Yg",
            "aud": "example-app",
            "exp": 1652535037,
            "iat": 1652448637,
            "at_hash": "o6m5X-zhodOAJQYyj30Omg",
            "c_hash": "J12uzCdpL_IITcDvif3mgg",
            "email": "myemail@somewhere.com",
            "email_verified": true,
            "name": "John Matthews",
            "preferred_username": "jwmatthews"
            }

      * Note the `email` field is configured in minikube to be the field for determing the username which the k8s API Server will use.  This is configured in `launch_minikube.sh` via the line:
        * `--extra-config=apiserver.oidc-username-claim=email`

# Test the JWT we obtained from Dex against the k8s-api-server
Before we can test interaction with the k8s-api-server let's configure a Role and RoleBinding for the 'email' address specified in our JWT.
1. Ensure you have MY_USERNAME set in your `SECRET.source_me` to match the email address in your JWT and ensure you have sourced this in your shell:  `source SECRET.source_me`
2. Run: `./install_rbac_example_role_and_binding.sh`
   * We know have a Role that can list pods and we have this applied via a RoleBinding to the user we will authenticate in via the JWT
3. Ensure you have the value of `export MY_K8S_SERVER="https://127.0.0.1:53908"` set to the k8s-api-server address you see in your `~/.kube/config`
   * Ideally we would have used the value of `$MY_MINIKUBE_IP` we defined earlier, but on my Mac my host is not able to access the k8s api server via that IP, I need to look at my `~/.kube/config` to find the IP:PORT which is listed for the minikube k8s api server
4. Test interaction with the k8s api server with your JWT via:
      $ ./test_client_to_k8s.sh 
      {
      "kind": "PodList",
      "apiVersion": "v1",
      "metadata": {
         "resourceVersion": "24438"
      },
      "items": []
      }
   * With above we expect to see we can List Pods in the `test` namespace as the user in our JWT.  This is sufficient to show the k8s api server is using the 'email' in the JWT to authenticate the user and then is leveraging the RoleBinding we created to check the user can do a List of Pods in the test namespace.
                                             

## Code of Conduct
Refer to Konveyor's Code of Conduct [here](https://github.com/konveyor/community/blob/main/CODE_OF_CONDUCT.md).
