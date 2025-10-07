#!/bin/sh

# ==============================================================================
# Virtualization Detection Script (virt.sh)
# ==============================================================================
# 
# POSIX-compliant version based on systemd's virt.c detection techniques
# Detects VMs, containers, chroot environments, and other virtualization types
#
# USAGE:
#   ./virt.sh [COMMAND]
#
# COMMANDS:
#   detect     Detect any virtualization (containers checked first) [default]
#   vm         Detect only virtual machines  
#   container  Detect only containers
#   chroot     Detect if running in chroot
#   help       Show usage information
#
# EXAMPLES:
#   ./virt.sh                 # Detect any virtualization
#   ./virt.sh vm             # Check only for VMs
#   ./virt.sh container      # Check only for containers
#   ./virt.sh chroot         # Check if in chroot
#
# EXIT CODES:
#   0: Detection successful
#   1: Error occurred
# ==============================================================================

# Strict error handling (POSIX compatible)
set -eu

# Enable trace mode if DEBUG environment variable is set
if [ -n "${DEBUG:-}" ]; then
    set -x
fi

# Virtualization type constants
VIRT_NONE="none"
VIRT_VM_OTHER="vm-other"
VIRT_CONTAINER_OTHER="container-other"

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# POSIX-compatible string contains function
str_contains() {
    case "$1" in
        *"$2"*) return 0 ;;
        *) return 1 ;;
    esac
}

# POSIX-compatible file reading with error handling
read_file_safe() {
    if [ -r "$1" ]; then
        cat "$1" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Check if command exists (POSIX compatible)
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ==============================================================================
# VM DETECTION FUNCTIONS
# ==============================================================================

# Detect virtualization via CPUID (x86/x64 only)
detect_vm_cpuid() {
    machine_type=$(uname -m)
    case "$machine_type" in
        i386|i686|x86_64|amd64)
            if command_exists lscpu; then
                hypervisor_info=$(lscpu 2>/dev/null | grep -i "hypervisor\|virtualization" || true)
                
                if [ -n "$hypervisor_info" ]; then
                    if str_contains "$hypervisor_info" "KVM"; then
                        echo "kvm"
                        return
                    elif str_contains "$hypervisor_info" "VMware"; then
                        echo "vmware"
                        return
                    elif str_contains "$hypervisor_info" "Microsoft" || str_contains "$hypervisor_info" "Hyper-V"; then
                        echo "microsoft"
                        return
                    elif str_contains "$hypervisor_info" "Xen"; then
                        echo "xen"
                        return
                    elif str_contains "$hypervisor_info" "QEMU"; then
                        echo "qemu"
                        return
                    elif str_contains "$hypervisor_info" "VirtualBox"; then
                        echo "oracle"
                        return
                    else
                        echo "$VIRT_VM_OTHER"
                        return
                    fi
                fi
            fi
            
            # Alternative: check /proc/cpuinfo for hypervisor flag
            if [ -r "/proc/cpuinfo" ]; then
                if grep -q "^flags.*hypervisor" "/proc/cpuinfo" 2>/dev/null; then
                    echo "$VIRT_VM_OTHER"
                    return
                fi
            fi
            ;;
    esac
    echo "$VIRT_NONE"
}

# Detect virtualization via DMI/SMBIOS information
detect_vm_dmi() {
    dmi_paths="/sys/class/dmi/id/product_name /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/board_vendor /sys/class/dmi/id/bios_vendor /sys/class/dmi/id/product_version"
    
    for dmi_path in $dmi_paths; do
        if [ -r "$dmi_path" ]; then
            vendor=$(read_file_safe "$dmi_path")
            if str_contains "$vendor" "KVM"; then
                echo "kvm"
                return
            elif str_contains "$vendor" "Amazon EC2"; then
                # Special handling for Amazon EC2 - check if it's bare metal
                if [ -r "/sys/class/dmi/id/product_name" ]; then
                    product_name=$(read_file_safe "/sys/class/dmi/id/product_name")
                    if str_contains "$product_name" ".metal"; then
                        echo "$VIRT_NONE"
                    else
                        echo "amazon"
                    fi
                else
                    echo "amazon"
                fi
                return
            elif str_contains "$vendor" "QEMU"; then
                echo "qemu"
                return
            elif str_contains "$vendor" "VMware" || str_contains "$vendor" "VMW"; then
                echo "vmware"
                return
            elif str_contains "$vendor" "innotek GmbH" || str_contains "$vendor" "VirtualBox" || str_contains "$vendor" "Oracle Corporation"; then
                echo "oracle"
                return
            elif str_contains "$vendor" "Xen"; then
                echo "xen"
                return
            elif str_contains "$vendor" "Bochs"; then
                echo "bochs"
                return
            elif str_contains "$vendor" "Parallels"; then
                echo "parallels"
                return
            elif str_contains "$vendor" "BHYVE"; then
                echo "bhyve"
                return
            elif str_contains "$vendor" "Hyper-V" || str_contains "$vendor" "Microsoft Corporation"; then
                echo "microsoft"
                return
            elif str_contains "$vendor" "Apple Virtualization"; then
                echo "apple"
                return
            elif str_contains "$vendor" "Google" || str_contains "$vendor" "Google Compute Engine"; then
                echo "google"
                return
            elif str_contains "$vendor" "OpenStack"; then
                echo "kvm"  # OpenStack typically uses KVM
                return
            elif str_contains "$vendor" "KubeVirt"; then
                echo "kvm"  # KubeVirt uses KVM
                return
            fi
        fi
    done
    echo "$VIRT_NONE"
}

# Detect virtualization via device tree (ARM/PowerPC/RISC-V)
detect_vm_device_tree() {
    machine_type=$(uname -m)
    case "$machine_type" in
        arm*|aarch64|ppc*|powerpc*|riscv*)
            # Check hypervisor/compatible file
            if [ -r "/proc/device-tree/hypervisor/compatible" ]; then
                hvtype=$(read_file_safe "/proc/device-tree/hypervisor/compatible")
                if str_contains "$hvtype" "linux,kvm"; then
                    echo "kvm"
                    return
                elif str_contains "$hvtype" "xen"; then
                    echo "xen"
                    return
                elif str_contains "$hvtype" "vmware"; then
                    echo "vmware"
                    return
                else
                    echo "$VIRT_VM_OTHER"
                    return
                fi
            fi
            
            # Check for PowerVM
            if [ -f "/proc/device-tree/ibm,partition-name" ] && \
               [ -f "/proc/device-tree/hmc-managed?" ] && \
               [ ! -f "/proc/device-tree/chosen/qemu,graphic-width" ]; then
                echo "powervm"
                return
            fi
            
            # Check device tree directory for QEMU indicators
            if [ -d "/proc/device-tree" ]; then
                # Look for fw-cfg (QEMU firmware configuration)
                if find "/proc/device-tree" -name "*fw-cfg*" -type f 2>/dev/null | grep -q .; then
                    echo "qemu"
                    return
                fi
                
                # Check compatible file
                if [ -r "/proc/device-tree/compatible" ]; then
                    compat=$(read_file_safe "/proc/device-tree/compatible")
                    if str_contains "$compat" "qemu,pseries"; then
                        echo "qemu"
                        return
                    elif str_contains "$compat" "linux,dummy-virt"; then
                        echo "$VIRT_VM_OTHER"
                        return
                    fi
                fi
            fi
            ;;
    esac
    echo "$VIRT_NONE"
}

# Detect Xen virtualization
detect_vm_xen() {
    if [ -d "/proc/xen" ]; then
        # Check if we're Dom0 (privileged domain)
        if [ -r "/sys/hypervisor/properties/features" ]; then
            features=$(read_file_safe "/sys/hypervisor/properties/features")
            if [ -n "$features" ]; then
                # Simple check - if features file exists and has content, check for Dom0
                # This is a simplified version of the bit manipulation in the original
                case "$features" in
                    *[8-9a-fA-F]*) 
                        # If hex value suggests Dom0 capabilities, don't report as virtualized
                        echo "$VIRT_NONE"
                        return
                        ;;
                esac
            fi
        fi
        
        # Check /proc/xen/capabilities
        if [ -r "/proc/xen/capabilities" ]; then
            caps=$(read_file_safe "/proc/xen/capabilities")
            if str_contains "$caps" "control_d"; then
                # Dom0 - privileged domain
                echo "$VIRT_NONE"
                return
            fi
        fi
        
        echo "xen"
    else
        echo "$VIRT_NONE"
    fi
}

# Detect via hypervisor sysfs interface
detect_vm_hypervisor() {
    if [ -r "/sys/hypervisor/type" ]; then
        hvtype=$(read_file_safe "/sys/hypervisor/type")
        case "$hvtype" in
            xen) echo "xen" ;;
            *) echo "$VIRT_VM_OTHER" ;;
        esac
    else
        echo "$VIRT_NONE"
    fi
}

# Detect User Mode Linux (UML)
detect_vm_uml() {
    if [ -r "/proc/cpuinfo" ]; then
        if grep -q "vendor_id.*User Mode Linux" "/proc/cpuinfo" 2>/dev/null; then
            echo "uml"
        else
            echo "$VIRT_NONE"
        fi
    else
        echo "$VIRT_NONE"
    fi
}

# Detect z/VM (IBM s390)
detect_vm_zvm() {
    machine_type=$(uname -m)
    case "$machine_type" in
        s390*) 
            if [ -r "/proc/sysinfo" ]; then
                vm_info=$(grep "VM00 Control Program" "/proc/sysinfo" 2>/dev/null || true)
                if str_contains "$vm_info" "z/VM"; then
                    echo "zvm"
                elif [ -n "$vm_info" ]; then
                    echo "kvm"
                else
                    echo "$VIRT_NONE"
                fi
            else
                echo "$VIRT_NONE"
            fi
            ;;
        *)
            echo "$VIRT_NONE"
            ;;
    esac
}

# ==============================================================================
# CONTAINER DETECTION FUNCTIONS  
# ==============================================================================

# Detect containers via environment files
detect_container_files() {
    # Check container-specific files (order matters - Docker should be last)
    if [ -f "/run/.containerenv" ]; then
        echo "podman"
        return
    elif [ -f "/.dockerenv" ]; then
        echo "docker"
        return
    fi
    
    echo "$VIRT_NONE"
}

# Detect containers via environment variables
detect_container_env() {
    container_env=""
    
    # Check various sources for container environment variable
    if [ -n "${container:-}" ]; then
        container_env="$container"
    elif [ -r "/run/systemd/container" ]; then
        container_env=$(read_file_safe "/run/systemd/container")
    elif [ -r "/run/host/container-manager" ]; then
        container_env=$(read_file_safe "/run/host/container-manager")
    elif [ "$(id -u)" -eq 0 ] && command_exists ps; then
        # Try to read from PID 1 environment (requires root)
        pid1_env=$(tr '\0' '\n' < "/proc/1/environ" 2>/dev/null | grep "^container=" | cut -d= -f2 || true)
        if [ -n "$pid1_env" ]; then
            container_env="$pid1_env"
        fi
    fi
    
    case "$container_env" in
        "") echo "$VIRT_NONE" ;;
        lxc) echo "lxc" ;;
        lxc-libvirt) echo "lxc-libvirt" ;;
        systemd-nspawn) echo "systemd-nspawn" ;;
        docker) echo "docker" ;;
        podman) echo "podman" ;;
        rkt) echo "rkt" ;;
        wsl) echo "wsl" ;;
        proot) echo "proot" ;;
        pouch) echo "pouch" ;;
        oci) 
            # OCI is generic, try to detect specific container
            specific=$(detect_container_files)
            if [ "$specific" = "$VIRT_NONE" ]; then
                echo "$VIRT_CONTAINER_OTHER"
            else
                echo "$specific"
            fi
            ;;
        *) echo "$VIRT_CONTAINER_OTHER" ;;
    esac
}

# Detect OpenVZ containers
detect_container_openvz() {
    # OpenVZ: /proc/vz exists but /proc/bc doesn't
    if [ -d "/proc/vz" ] && [ ! -d "/proc/bc" ]; then
        echo "openvz"
    else
        echo "$VIRT_NONE"
    fi
}

# Detect Windows Subsystem for Linux (WSL)
detect_container_wsl() {
    if [ -r "/proc/sys/kernel/osrelease" ]; then
        osrelease=$(read_file_safe "/proc/sys/kernel/osrelease")
        if str_contains "$osrelease" "Microsoft" || str_contains "$osrelease" "WSL"; then
            echo "wsl"
        else
            echo "$VIRT_NONE"
        fi
    else
        echo "$VIRT_NONE"
    fi
}

# Detect proot (userspace chroot)
detect_container_proot() {
    if [ -r "/proc/self/status" ]; then
        tracer_pid=$(grep "^TracerPid:" "/proc/self/status" 2>/dev/null | awk '{print $2}' || echo "0")
        
        if [ "$tracer_pid" != "0" ] && [ -r "/proc/$tracer_pid/comm" ]; then
            tracer_comm=$(read_file_safe "/proc/$tracer_pid/comm")
            if str_contains "$tracer_comm" "proot"; then
                echo "proot"
            else
                echo "$VIRT_NONE"
            fi
        else
            echo "$VIRT_NONE"
        fi
    else
        echo "$VIRT_NONE"
    fi
}

# Check if running in PID namespace (indicates containerization)
detect_container_pidns() {
    if [ -r "/proc/self/ns/pid" ] && [ -r "/proc/1/ns/pid" ]; then
        self_pidns=$(readlink "/proc/self/ns/pid" 2>/dev/null || true)
        proc1_pidns=$(readlink "/proc/1/ns/pid" 2>/dev/null || true)
        
        if [ -n "$self_pidns" ] && [ -n "$proc1_pidns" ] && [ "$self_pidns" != "$proc1_pidns" ]; then
            echo "$VIRT_CONTAINER_OTHER"
        else
            echo "$VIRT_NONE"
        fi
    else
        echo "$VIRT_NONE"
    fi
}

# ==============================================================================
# MAIN DETECTION FUNCTIONS
# ==============================================================================

# Detect virtual machines using multiple methods
detect_vm() {
    # Detection order follows systemd's virt.c logic
    
    # 1. Check DMI first (catches Oracle, Amazon, Parallels, etc.)
    result=$(detect_vm_dmi)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    # 2. Check UML
    result=$(detect_vm_uml)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    # 3. Check Xen
    result=$(detect_vm_xen)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    # 4. Check CPUID
    result=$(detect_vm_cpuid)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    # 5. Check hypervisor sysfs
    result=$(detect_vm_hypervisor)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    # 6. Check device tree (ARM/PowerPC/RISC-V)
    result=$(detect_vm_device_tree)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    # 7. Check z/VM (s390)
    result=$(detect_vm_zvm)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    echo "$VIRT_NONE"
}

# Detect containers using multiple methods
detect_container() {
    # 1. Check OpenVZ first
    result=$(detect_container_openvz)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    # 2. Check WSL
    result=$(detect_container_wsl)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    # 3. Check proot
    result=$(detect_container_proot)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    # 4. Check environment variables
    result=$(detect_container_env)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    # 5. Check container files
    result=$(detect_container_files)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    # 6. Check PID namespace as last resort
    result=$(detect_container_pidns)
    if [ "$result" != "$VIRT_NONE" ]; then
        echo "$result"
        return
    fi
    
    echo "$VIRT_NONE"
}

# Detect any virtualization (containers first, then VMs)
detect_virtualization() {
    # Check containers first (following systemd logic)
    container_result=$(detect_container)
    if [ "$container_result" != "$VIRT_NONE" ]; then
        echo "$container_result"
        return
    fi
    
    # Then check VMs
    vm_result=$(detect_vm)
    echo "$vm_result"
}

# ==============================================================================
# CHROOT DETECTION
# ==============================================================================

# Detect if running in chroot environment
detect_chroot() {
    # Check environment variable first
    if [ "${SYSTEMD_IN_CHROOT:-}" = "1" ]; then
        echo "chroot"
        return
    fi
    
    # Legacy environment variable
    if [ "${SYSTEMD_IGNORE_CHROOT:-}" = "1" ]; then
        echo "none"
        return
    fi
    
    # Compare root directory inodes
    if [ -r "/proc/1/root" ] && [ -r "/" ]; then
        if command_exists stat; then
            root_inode=$(stat -c %i / 2>/dev/null || echo "0")
            proc1_root_inode=$(stat -c %i /proc/1/root 2>/dev/null || echo "1")
            
            if [ "$root_inode" != "0" ] && [ "$proc1_root_inode" != "0" ] && [ "$root_inode" != "$proc1_root_inode" ]; then
                echo "chroot"
                return
            fi
        fi
    fi
    
    # If /proc is not mounted and we're not PID 1, likely in chroot
    if [ ! -d "/proc/self" ]; then
        current_pid=$(exec sh -c 'echo $PPID')
        if [ "$(id -u)" -ne 0 ] || [ "$current_pid" -ne 1 ]; then
            echo "chroot"
            return
        fi
    fi
    
    echo "none"
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

# Display usage information
show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Detect virtualization environment using systemd's detection techniques (POSIX compatible)

Commands:
  detect     Detect any virtualization (containers checked first) [default]
  vm         Detect only virtual machines
  container  Detect only containers  
  chroot     Detect if running in chroot
  help       Show this help

Examples:
  $0                 # Detect any virtualization
  $0 vm             # Check only for VMs
  $0 container      # Check only for containers
  $0 chroot         # Check if in chroot

Exit codes:
  0: Detection successful
  1: Error occurred

Virtualization types detected:
  VMs: kvm, qemu, vmware, xen, microsoft, oracle, amazon, apple, google, 
       parallels, bhyve, bochs, uml, zvm, powervm, vm-other, none
  Containers: docker, podman, lxc, lxc-libvirt, systemd-nspawn, openvz,
              wsl, proot, rkt, pouch, container-other, none
  Other: chroot, none

Note: This is a POSIX-compliant version that works with any POSIX shell.
EOF
}

# Main function
main() {
    command="${1:-detect}"
    
    case "$command" in
        detect|--detect)
            detect_virtualization
            ;;
        vm|--vm)
            detect_vm
            ;;
        container|--container)
            detect_container
            ;;
        chroot|--chroot)
            detect_chroot
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            printf "Unknown command: %s\n" "$command" >&2
            printf "Use '%s help' for usage information\n" "$0" >&2
            return 1
            ;;
    esac
}

# Execute main function if script is run directly (not sourced)
# POSIX-compatible way to check if script is being sourced
case "${0##*/}" in
    virt.sh) main "$@" ;;
esac