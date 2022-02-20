#Set-PowerCliConfiguration -InvalidCertificateAction Ignore

function Get-VMTerraformDetails($VIServer, $VM) {
  Connect-VIServer $VIServer

  $vms = Get-VM $VM

  foreach($vm in $vms) {
    # Get Basic VM Info
    $name = $vm.name
    $datacenter = $vm.VMHost | Get-Datacenter | Select -ExpandProperty Name
    $cluster = $vm.VMHost | Get-Cluster | Select -ExpandProperty Name
    $networks = $vm | Get-NetworkAdapter | Select -ExpandProperty Name

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
    $num_disks = $disk_labels.Count
    $count = 0
    while($num_disks -ne $count) {
      $disk_info["disk_label"] += $disk_labels[$count]
      $disk_info["disk_size"] += $disk_sizes[$count]
      $disk_info["disk_prov"] += $disk_provisioning[$count]

      $count += 1
    }

    Write-Host $name
  }
} 
