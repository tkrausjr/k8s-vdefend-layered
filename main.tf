terraform {
  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = "~> 3.0"
    }
  }
}

provider "nsxt" {
  host                 = var.nsx_manager
  username             = var.nsx_username
  password             = var.nsx_password
  allow_unverified_ssl = var.allow_unverified_ssl
}

#############################################
# Data Sources - Antrea Container Cluster
#############################################

data "nsxt_policy_container_cluster" "antrea_cluster" {
  id = var.cluster_control_plane_id
}

#############################################
# Custom Services - Port Definitions
#############################################

resource "nsxt_policy_service" "tcp_5000" {
  display_name = "tcp-5000"
  description  = "HTTP port 5000"
  
  l4_port_set_entry {
    display_name      = "tcp-5000"
    protocol          = "TCP"
    destination_ports = ["5000"]
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

resource "nsxt_policy_service" "tcp_5001" {
  display_name = "tcp-5001"
  description  = "Order service port 5001"
  
  l4_port_set_entry {
    display_name      = "tcp-5001"
    protocol          = "TCP"
    destination_ports = ["5001"]
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

resource "nsxt_policy_service" "tcp_5002" {
  display_name = "tcp-5002"
  description  = "Cart service port 5002"
  
  l4_port_set_entry {
    display_name      = "tcp-5002"
    protocol          = "TCP"
    destination_ports = ["5002"]
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

resource "nsxt_policy_service" "tcp_5003" {
  display_name = "tcp-5003"
  description  = "Users service port 5003"
  
  l4_port_set_entry {
    display_name      = "tcp-5003"
    protocol          = "TCP"
    destination_ports = ["5003"]
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

resource "nsxt_policy_service" "tcp_5432" {
  display_name = "tcp-5432"
  description  = "PostgreSQL port 5432"
  
  l4_port_set_entry {
    display_name      = "tcp-5432"
    protocol          = "TCP"
    destination_ports = ["5432"]
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

#############################################
# Security Groups - Based on K8s Labels
#############################################

resource "nsxt_policy_group" "music_store_frontend" {
  display_name = "Music-store-frontend"
  description  = "Music store frontend service"
  domain       = "default"
  group_type   = "ANTREA"

  criteria {
    condition {
      member_type = "Namespace"
      key         = "Name"
      operator    = "EQUALS"
      value       = "music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:app-name|music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:env|prod"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:app|music-store-1"
    }
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

resource "nsxt_policy_group" "store_service" {
  display_name = "store-service"
  description  = "Music store main service"
  domain       = "default"
  group_type   = "ANTREA"

  criteria {
    condition {
      member_type = "Namespace"
      key         = "Name"
      operator    = "EQUALS"
      value       = "music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:app-name|music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:env|prod"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:service-name|store"
    }
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

resource "nsxt_policy_group" "cart_service" {
  display_name = "cart-service"
  description  = "Shopping cart service"
  domain       = "default"
  group_type   = "ANTREA"

  criteria {
    condition {
      member_type = "Namespace"
      key         = "Name"
      operator    = "EQUALS"
      value       = "music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:app-name|music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:env|prod"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:service-name|cart"
    }
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

resource "nsxt_policy_group" "order_service" {
  display_name = "order-service"
  description  = "Order processing service"
  domain       = "default"
  group_type   = "ANTREA"

  criteria {
    condition {
      member_type = "Namespace"
      key         = "Name"
      operator    = "EQUALS"
      value       = "music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:app-name|music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:env|prod"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:service-name|order"
    }
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

resource "nsxt_policy_group" "users_service" {
  display_name = "users-service"
  description  = "User management service"
  domain       = "default"
  group_type   = "ANTREA"

  criteria {
    condition {
      member_type = "Namespace"
      key         = "Name"
      operator    = "EQUALS"
      value       = "music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:app-name|music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:env|prod"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:service-name|users"
    }
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

resource "nsxt_policy_group" "database_service" {
  display_name = "database-service"
  description  = "PostgreSQL database service"
  domain       = "default"
  group_type   = "ANTREA"

  criteria {
    condition {
      member_type = "Namespace"
      key         = "Name"
      operator    = "EQUALS"
      value       = "music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:app-name|music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:env|prod"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:service-name|database"
    }
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

resource "nsxt_policy_group" "music_store_all" {
  display_name = "music-store-all"
  description  = "All music store services"
  domain       = "default"
  group_type   = "ANTREA"

  criteria {
    condition {
      member_type = "Namespace"
      key         = "Name"
      operator    = "EQUALS"
      value       = "music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:app-name|music-store"
    }
    condition {
      member_type = "Pod"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "dis:k8s:env|prod"
    }
  }

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

#############################################
# Security Policy - Parent Policy
#############################################

resource "nsxt_policy_parent_security_policy" "music_store_prod" {
  display_name    = "tf-music-store-prod"
  description     = "Antrea-integrated parent security policy for music store production"
  category        = "Application"
  domain          = "default"
  sequence_number = 499999
  stateful        = true
  tcp_strict      = true

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }

  tag {
    scope = "environment"
    tag   = "production"
  }

  tag {
    scope = "cluster"
    tag   = var.cluster_control_plane_id
  }
}

#############################################
# Security Policy Container Cluster Association
#############################################

resource "nsxt_policy_security_policy_container_cluster" "music_store_antrea" {
  display_name           = "tf-music-store-prod-cluster"
  description            = "Associates music store policy with Antrea cluster"
  policy_path            = nsxt_policy_parent_security_policy.music_store_prod.path
  container_cluster_path = data.nsxt_policy_container_cluster.antrea_cluster.path

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }
}

#############################################
# Security Rules
#############################################

# Rule 1: Avi SE + Antrea node gateways -> frontend
resource "nsxt_policy_security_policy_rule" "frontend" {
  display_name       = "frontend-avi"
  description        = "Avi SE + Antrea node gateways -> frontend:5000"
  policy_path        = nsxt_policy_parent_security_policy.music_store_prod.path
  sequence_number    = 249999
  action             = "ALLOW"
  direction          = "IN"
  ip_version         = "IPV4_IPV6"
  logged             = true
  disabled           = false

  # Avi SE data IP + antrea-gw0 of each node (NodePort/LB traffic is SNATed to it)
  source_groups      = ["100.64.32.0/24", "240.0.0.1", "240.0.1.1", "240.0.2.1", "240.0.3.1"]
  # destination_groups omitted for Antrea - use scope (applied to) instead
  services           = [nsxt_policy_service.tcp_5000.path]
  scope              = [nsxt_policy_group.music_store_frontend.path]

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }

  depends_on = [nsxt_policy_group.music_store_frontend]
}

# Rule 2: Store -> Database
# Service-to-service flows (store->cart/users/order, cart->order) are owned by the
# Application team as a native Antrea ACNP: see k8s/app-svc-to-svc.yaml
resource "nsxt_policy_security_policy_rule" "store_to_database" {
  display_name       = "store->database"
  description        = "Allow store service to access database"
  policy_path        = nsxt_policy_parent_security_policy.music_store_prod.path
  sequence_number    = 15624
  action             = "ALLOW"
  direction          = "IN"
  ip_version         = "IPV4_IPV6"
  logged             = false
  disabled           = false

  source_groups      = [nsxt_policy_group.store_service.path]
  # destination_groups omitted for Antrea - use scope (applied to) instead
  services           = [nsxt_policy_service.tcp_5432.path]
  scope              = [nsxt_policy_group.database_service.path]

  tag {
    scope = "managed-by"
    tag   = "terraform"
  }

  depends_on = [nsxt_policy_group.store_service, nsxt_policy_group.database_service]
}

# Default deny is NOT enforced here. A DROP in the Application category lands in
# Antrea tier nsx-category-application (priority 4), which is evaluated before
# app-team ANNP/ACNP (application tier, 250) and would make them unreachable.
# Default deny lives in the Antrea baseline tier instead: see k8s/baseline-default-deny.yaml
