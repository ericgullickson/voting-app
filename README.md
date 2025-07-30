# Example Voting App

A simple distributed application running across multiple Docker containers.

## Getting started

There are two ways to deploy this application. The first and primary use for this repo is on five separate virtual machines. This was tested using the ubuntu cloud 24.04 image but has logic for RHEL based systems. 

Deploy the servers using the [cloud-init.yml](cloud-init.yml) file for server configuration. This installs packages and sets up docker for you. 

Once they are deployed, log into one and launch the setup app from any of them. 
```
nutanix@ubuntu:~$ voting-app/setup_voting_app.py
```

It will prompt you for the IP addresses of all the VM's as well as what options you'd like the votes to be for. It will also give you the ability to use SSH keys or passwords depending on your environment. 

The Docker login uses personal access token for scripted access in the case you are rate limited from Docker.

```
nutanix@ubuntu:~$ voting-app/setup_voting_app.py
Enter IP addresses for each service:
Vote: 192.168.252.193
Results: 192.168.252.173
Redis: 192.168.252.146
Worker: 192.168.252.118
Database: 192.168.252.128
Option A (default: Hi-C):
Option B (default: Tang):
Docker Hub Username (optional, press Enter to skip): 
Docker Hub Personal Access Token (dckr_pat_...): 
SSH Username: nutanix
SSH Private Key Path (press Enter to auto-detect):
No SSH keys found in ~/.ssh/
SSH Password:

Connecting to 192.168.252.193 (Vote)...
Setting hostname to 'vote'...
Updating .env file with IP addresses...
Running docker compose for vote...
```

Once it's finished you can navigate to the Vote IP to cast your votes. The web pages are standard HTTP. i.e. http://192.168.252.193

If you want to randomly generate votes you can use the [generate-votes.sh](generate-votes.sh) file. 

```
nutanix@vote:~$ voting-app/generate-votes.sh
Random Voting Script
===================

Enter vote URL [default: http://vote/]: http://192.168.252.193
Using URL: http://192.168.252.193

Voting mode:
1) Enter total number of votes
2) Run continuously (CTRL+C to stop)

Choose option (1 or 2): 2
Running in infinite mode - press CTRL+C to stop

Starting infinite random voting process...
Sending 60 votes for option A...
Waiting 5 seconds before next batch... (Total votes sent: 60)
```

## Run the app in Kubernetes

The folder k8s-specifications contains the YAML specifications of the Voting App's services.

Run the following command to create the deployments and services. Note it will create these resources in your current namespace (`default` if you haven't changed it.)

```shell
kubectl create -f k8s-specifications/
```

The `vote` web app is then available on port 31000 on each host of the cluster, the `result` web app is available on port 31001.

To remove them, run:

```shell
kubectl delete -f k8s-specifications/
```

## Architecture

![Architecture diagram](architecture.excalidraw.png)

* A front-end web app in [Python](/vote) which lets you vote between two options
* A [Redis](https://hub.docker.com/_/redis/) which collects new votes
* A [.NET](/worker/) worker which consumes votes and stores them in…
* A [Postgres](https://hub.docker.com/_/postgres/) database backed by a Docker volume
* A [Node.js](/result) web app which shows the results of the voting in real time

## Notes

The voting application only accepts one vote per client browser. It does not register additional votes if a vote has already been submitted from a client.

This isn't an example of a properly architected perfectly designed distributed app... it's just a simple
example of the various types of pieces and languages you might see (queues, persistent data, etc). It's purpose is for demostrating and testing infrastructure or security. 