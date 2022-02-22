#Set-PowerCliConfiguration -InvalidCertificateAction Ignore

function Get-VMTerraformDetails($VIServer, $VM) {
  Connect-VIServer $VIServer

  #Define the array of VMs and the output array of objects
  $vms = Get-VM $VM
  $object_array = @()

  foreach($vm in $vms) {
    # Get Basic VM Info
    $name = $vm.name
    $datacenter = $vm.VMHost | Get-Datacenter | Select -ExpandProperty Name
    $cluster = $vm.VMHost | Get-Cluster | Select -ExpandProperty Name
    $networks = $vm | Get-NetworkAdapter | Select -ExpandProperty NetworkName

    # Get VM CPU/Mem
    $num_cpus = $vm.NumCpu
    $mem = $vm.MemoryGB * 1024

    # Get VM Datastore
    $datastore = $vm | Get-Datastore | Select -ExpandProperty Name

    # Get VM Disk Info
    $disks = $vm | Get-HardDisk
    $disk_labels = $disks | Select -ExpandProperty Name
    $disk_sizes = $disks | Select -ExpandProperty CapacityGB
    $disk_provisioning = @()
  
    foreach ($disk in $disks) {
      $is_thin = $disk | Select -ExpandProperty StorageFormat
    
      if($is_thin -eq "Thin") {
        $disk_provisining += "True"
      } 
      else {
        $disk_provisining += "False"
      }
    }

    # Define VM Disk info dict
    $disk_info = @{
                   disk_label = @()
                   disk_size = @()
                   disk_prov = @()
                 }

    # Populate disk_info with relevant information
#    $num_disks = $disk_labels.Count
#    $count = 0
#    while($num_disks -ne $count) {
     $disk_info["disk_label"] = $disk_labels
     $disk_info["disk_size"] = $disk_sizes
     $disk_info["disk_prov"] = $disk_provisioning

#      $count += 1
#    }

    # Create the custom object to return to the console
    $vmInfo = [PSCustomObject]@{
      name = $name
      datacenter = $datacenter
      cluster = $cluster
      network_info = $networks
      cpu = $num_cpus
      mem = $mem
      datastore = $datastore
      disk_info = $disk_info
    }

    # Append the custom object to the array, then clear the object
    $object_array += $vmInfo
    $vmInfo = ""
  }

  return $object_array
} 

function Generate-TerraformFiles() {
  param($vmname, 
        $datacenter, 
        $cluster, 
        $networks, 
        $cpu, 
        $mem,
        $datastore,
        [hashtable] $disk_info)

  # Define the provider block for terraform
  $provider_block = " `
provider `"vsphere`" { `
  user                 = var.vsphere_user `
  password             = var.vsphere_password `
  vsphere_server       = var.vsphere_server `
  allow_unverified_ssl = true `
}`n"
  
  # Define the datacenter block for terraform
  $datacenter_block = "`
data `"vsphere_datacenter`" `"dc`" { `
  name = `"REPLACE_THIS`" `
}`n"

  # Define the datastore block for terraform
  $datastore_block = "`
data `"vsphere_datastore`" `"datastore`" { `
  name          = `"REPLACE_THIS`" `
  datacenter_id = data.vsphere_datacenter.dc.id `
}`n"

  # Define the cluster block for terraform
  $cluster_block = "`
data `"vsphere_compute_cluster`" `"cluster`" { `
  name          = `"REPLACE_THIS`" `
  datacenter_id = data.vsphere_datacenter.dc.id `
}`n"

  # Define the network block for terraform
  $network_block = "`
data `"vsphere_network`" `"NETWORK_ID`" { `
  name          = `"NETWORK_NAME`" `
  datacenter_id = data.vsphere_datacenter.dc.id `
}`n"

  # Define the resource block for terraform
  $resource_block = "`
resource `"vsphere_virtual_machine`" `"vm`" {  `
  name             = `"VM_NAME`"  `
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id `
  datastore_id     = data.vsphere_datastore.datastore.id `
  wait_for_guest_net_timeout = 0 `
  wait_for_guest_ip_timeout  = 0 `
  wait_for_guest_net_routable = false `
  num_cpus = CPU_COUNT `
  memory   = MEMORY_COUNT `
  NETWORK_BLOCKS `
  DISK_BLOCKS `
}"
  
  # Define the network block for within the resource block
  $network_sub_block = "`
  network_interface { `
    network_id = data.vsphere_network.NETWORK_ID.id `
  }`n"

  # Define the disk block for within the resource block
  $disk_sub_block = "`
  disk { `
    label = `"DISK_NAME`" `
    size = `"DISK_SIZE`" `
    thin_provisioned = `"DISK_PROV`" `
  }`n"

  # Start the terraform file
  $terraform_output = $provider_block
  $terraform_output += $datacenter_block.replace('REPLACE_THIS', $datacenter)
  $terraform_output += $datastore_block.replace('REPLACE_THIS', $datastore)
  $terraform_output += $cluster_block.replace('REPLACE_THIS', $cluster)

  # Define a string to contain the network sub blocks
  $network_sub_blocks = ""

  # Define network blocks for each network on the VM
  foreach( $network in $networks ) {
    # Replace the Network Name with the portgroup in vsphere
    $net_block = $network_block.replace('NETWORK_NAME', $network)
 
    # Remove the space and give a unique identifier to the network
    $network = $network.replace(" ", "")
    $net_block = $net_block.replace('NETWORK_ID', $network)

    # Modify and append a network sub block for each network
    $network_sub_blocks += $network_sub_block.replace('NETWORK_ID', $network)

    $terraform_output += $net_block
  }

  # Define disk blocks for each disk on the machine
  Write-Host "Entering Disk Zone"
  Write-Host $disk_info.Keys
  Write-Host $disk_info["disk_label"]
  $disk_sub_blocks = ""
  $count = 0
  while ( $count -lt $disk_info["disk_label"].Count ) {
    $temp_disk_block = $disk_sub_block.replace('DISK_NAME', $disk_info["disk_label"][$count])
    $temp_disk_block = $temp_disk_block.replace('DISK_SIZE', $disk_info["disk_size"][$count])

    $disk_sub_blocks += $temp_disk_block 
    Write-Host $disk_sub_blocks

    $count += 1
  } 
  Write-Host "Exiting Disk Zone"


  # Add the resource block 
  $rsc_block = $resource_block.replace('VM_NAME', $vmname) 
  $rsc_block = $rsc_block.replace('CPU_COUNT', $cpu)
  $rsc_block = $rsc_block.replace('MEM_COUNT', $mem)
  $rsc_block = $rsc_block.replace('NETWORK_BLOCKS', $network_sub_blocks)
  $rsc_block = $rsc_block.replace('DISK_BLOCKS', $disk_sub_blocks)

  $terraform_output += $rsc_block

  $filename = ".\\" + $vmname + ".tf"
  $terraform_output | Out-File -FilePath $filename
}
