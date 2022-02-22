 
provider "vsphere" { 
  user                 = var.vsphere_user 
  password             = var.vsphere_password 
  vsphere_server       = var.vsphere_server 
  allow_unverified_ssl = true 
}

data "vsphere_datacenter" "dc" { 
  name = "Datacenter" 
}

data "vsphere_datastore" "datastore" { 
  name          = "datastore1" 
  datacenter_id = data.vsphere_datacenter.dc.id 
}

data "vsphere_compute_cluster" "cluster" { 
  name          = "Cluster" 
  datacenter_id = data.vsphere_datacenter.dc.id 
}

data "vsphere_network" "dvportgroup-35" { 
  name          = "dvportgroup-35" 
  datacenter_id = data.vsphere_datacenter.dc.id 
}

data "vsphere_network" "VMNetwork" { 
  name          = "VM Network" 
  datacenter_id = data.vsphere_datacenter.dc.id 
}

resource "vsphere_virtual_machine" "vm" {  
  name             = "DC1"  
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id 
  datastore_id     = data.vsphere_datastore.datastore.id 
  wait_for_guest_net_timeout = 0 
  wait_for_guest_ip_timeout  = 0 
  wait_for_guest_net_routable = false 
  num_cpus = 2 
  memory   = MEMORY_COUNT 
  
  network_interface { 
    network_id = data.vsphere_network.dvportgroup-35.id 
  }

  network_interface { 
    network_id = data.vsphere_network.VMNetwork.id 
  }
 
  
  disk { 
    label = "H" 
    size = "100" 
    thin_provisioned = "DISK_PROV" 
  }
 
}
