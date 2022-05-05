#Set-PSDebug -Trace 1

$CONTROLLER_NO = 1
$WORKER_NO = 2

$Location = "c:\Users\TobiasPolley\.cl"

If((Test-Path $Location) -eq $False) {
	New-Item -ItemType directory -Path $Location
}
Set-Location -Path $Location

$SSH_Key_File = "$($Location)\id_rsa.pub"

If((Test-Path $SSH_Key_File) -eq $False) {
	& ssh-keygen.exe -C Tobias -f id_rsa -N """"
}

$SSH_Key = Get-Content -Path $SSH_Key_File

& gcloud config set project k8s-3-2021-324816

& gcloud compute networks create example-k8s --subnet-mode custom

& gcloud compute networks subnets create k8s-nodes --network example-k8s --range 10.240.0.0/24 --region=europe-west1

& gcloud compute firewall-rules create example-k8s-allow-internal --allow "tcp,udp,icmp,ipip" --network example-k8s --source-ranges 10.240.0.0/24

& gcloud compute firewall-rules create example-k8s-allow-external --allow "tcp:22,tcp:6443,icmp" --network example-k8s --source-ranges 0.0.0.0/0

for ($i=1; $i -le $CONTROLLER_NO; $i++) {
	
& gcloud compute instances create "controller-$($i)" --async --boot-disk-size 200GB --can-ip-forward --image-family ubuntu-2004-lts --image-project ubuntu-os-cloud --machine-type n1-standard-2 --private-network-ip "10.240.0.$(10 + $i)" --scopes "compute-rw,storage-ro,service-management,service-control,logging-write,monitoring" --subnet k8s-nodes --zone europe-west1-b --tags "example-k8s,controller" "--metadata=block-project-ssh-keys=true,ssh-keys=Tobias:$($SSH_Key)"

}

for ($i=1; $i -le $WORKER_NO; $i++) {

& gcloud compute instances create "worker-$($i)" --async --boot-disk-size 200GB --can-ip-forward --image-family ubuntu-2004-lts --image-project ubuntu-os-cloud --machine-type n1-standard-2    --private-network-ip "10.240.0.$(20 + $i)" --scopes "compute-rw,storage-ro,service-management,service-control,logging-write,monitoring" --subnet k8s-nodes  --zone europe-west1-b --tags "example-k8s,worker" "--metadata=block-project-ssh-keys=true,ssh-keys=Tobias:$($SSH_Key)"

}

& gcloud compute instances list

$controller_ip = @()
$worker_ip = @()

for ($i=1; $i -le $CONTROLLER_NO; $i++) {
	$controller_ip += & { gcloud compute instances list --filter="name=(controller-$i)" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" }
	
}

for ($i=1; $i -le $WORKER_NO; $i++) {
	$worker_ip += & { gcloud compute instances list --filter="name=(worker-$i)" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" }
	
}

for ($i=1; $i -le $CONTROLLER_NO; $i++) {
	Write-Output "controller$($i): $($controller_ip[$i-1])"
}
for ($i=1; $i -le $WORKER_NO; $i++) {
	Write-Output "worker$($i): $($worker_ip[$i-1])"
}

$controller_ip + $worker_ip | ForEach-Object {
	Do {
		& ssh -i id_rsa -oStrictHostKeyChecking=accept-new "Tobias@$($PSItem)" echo 1
		Start-Sleep -Seconds 1
	} while ($LASTEXITCODE -ne 0)
	
	& ssh -i id_rsa "Tobias@$($PSItem)" sudo apt update
	& ssh -i id_rsa "Tobias@$($PSItem)" sudo apt install -y docker.io apt-transport-https curl
	& ssh -i id_rsa "Tobias@$($PSItem)" sudo systemctl enable docker.service
	& ssh -i id_rsa "Tobias@$($PSItem)" "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -"
	& ssh -i id_rsa "Tobias@$($PSItem)" @'
"sudo bash -c ""echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' >  /etc/apt/sources.list.d/kubernetes.list"" "
'@
	& ssh -i id_rsa "Tobias@$($PSItem)" sudo apt update
	& ssh -i id_rsa "Tobias@$($PSItem)" sudo apt-get install -y kubelet kubeadm kubectl
	& ssh -i id_rsa "Tobias@$($PSItem)" sudo apt-mark hold kubelet kubeadm kubectl
	Write-Output "{""exec-opts"": [""native.cgroupdriver=systemd""]}" | & ssh -i id_rsa "Tobias@$($PSItem)" sudo tee /etc/docker/daemon.json
	& ssh -i id_rsa "Tobias@$($PSItem)" sudo systemctl restart docker
	
}

& gcloud compute instance-groups unmanaged create master-nodes --zone=europe-west1-b
& gcloud compute instance-groups unmanaged add-instances master-nodes --zone=europe-west1-b --instances=controller-1
& gcloud compute health-checks create tcp kubernetes-api --region=europe-west1 --port=6443
& gcloud compute backend-services create kubernetes-api --protocol=tcp --region=europe-west1 --health-checks=kubernetes-api --health-checks-region=europe-west1
& gcloud compute backend-services add-backend kubernetes-api --region=europe-west1 --instance-group=master-nodes --instance-group-zone=europe-west1-b
& gcloud compute addresses create kubernetes-api-ip --region europe-west1
& gcloud compute forwarding-rules create network-lb-forwarding-rule --load-balancing-scheme external --region europe-west1 --ports 6443 --address kubernetes-api-ip --backend-service kubernetes-api

$kube_api_ip = & { gcloud compute addresses list "--filter=name=kubernetes-api-ip" "--format=value(address)" }

& ssh -i id_rsa "Tobias@$($controller_ip[0])" sudo kubeadm init --upload-certs --pod-network-cidr 192.168.0.0/16 --control-plane-endpoint "$($kube_api_ip):6443"

$join_command = & { ssh -i id_rsa "Tobias@$($controller_ip[0])" sudo kubeadm token create --print-join-command }

$certificate_key = & { ssh -i id_rsa "Tobias@$($controller_ip[0])" "sudo kubeadm init phase upload-certs --upload-certs | tail -n 1" }

for ($i=2; $i -le $CONTROLLER_NO; $i++) {
	& ssh -i id_rsa "Tobias@$($controller_ip[$i-1])" sudo $join_command --control-plane --certificate-key $certificate_key
}

for ($i=1; $i -le $WORKER_NO; $i++) {
	& ssh -i id_rsa "Tobias@$($worker_ip[$i-1])" sudo $join_command
}

if ($CONTROLLER_NO -gt 1) {
	$cs = ""
	for ($i=2; $i -le $CONTROLLER_NO; $i++) {
		$cs += "controller-$($i),"
	}
	& gcloud compute instance-groups unmanaged add-instances master-nodes "--zone=europe-west1-b" "--instances=$cs"
}

& ssh -i id_rsa "Tobias@$($controller_ip[0])" @'
"mkdir -p $HOME/.kube"
'@
& ssh -i id_rsa "Tobias@$($controller_ip[0])" @'
"sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config"
'@
& ssh -i id_rsa "Tobias@$($controller_ip[0])" @'
"sudo chown $(id -u):$(id -g) $HOME/.kube/config"
'@

& ssh -i id_rsa "Tobias@$($controller_ip[0])" kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
