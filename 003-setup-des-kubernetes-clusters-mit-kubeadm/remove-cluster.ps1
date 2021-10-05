#Set-PSDebug -Trace 1

$CONTROLLER_NO = 1
$WORKER_NO = 2

$Location = "c:\Users\Tobias\.cl"

Set-Location -Path $Location


& gcloud compute forwarding-rules delete network-lb-forwarding-rule --region europe-west1 -q
& gcloud compute addresses delete kubernetes-api-ip --region europe-west1 -q
& gcloud compute backend-services delete kubernetes-api --region=europe-west1 -q
& gcloud compute health-checks delete kubernetes-api --region=europe-west1 -q
& gcloud compute instance-groups unmanaged delete master-nodes --zone=europe-west1-b -q

$cs = @()
for ($i=1; $i -le $CONTROLLER_NO; $i++) {
	$cs += "controller-$($i)"
}
for ($i=1; $i -le $WORKER_NO; $i++) {
	$cs += "worker-$($i)"
}

& gcloud compute instances delete @cs --zone europe-west1-b -q

& gcloud compute firewall-rules delete example-k8s-allow-external -q
& gcloud compute firewall-rules delete example-k8s-allow-internal -q

& gcloud compute networks subnets delete k8s-nodes --region=europe-west1 -q

& gcloud compute networks delete example-k8s -q