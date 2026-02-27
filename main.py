#!/usr/bin/env python3
"""
CA7 Registry Cleaner - Terminal Tool
Scans HKU\...\Wow6432Node\CLSID for entries ENDING with CA7 and allows deletion
"""

import sys
import os
import ctypes
import logging
import winreg
import click
from typing import List, Tuple, Optional, Dict

# Windows-only check
if os.name != "nt":
    sys.exit("❌ This tool can only run on Windows.")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%H:%M:%S"
)
logger = logging.getLogger(__name__)


def is_admin() -> bool:
    """Check if running with administrator privileges."""
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception as exc:
        logger.error(f"Failed to check admin status: {exc}")
        return False


def run_as_admin():
    """Re-run the script with admin privileges via UAC."""
    if not is_admin():
        try:
            ctypes.windll.shell32.ShellExecuteW(
                None,
                "runas",
                sys.executable,
                " ".join(f'"{arg}"' for arg in sys.argv),
                None,
                1
            )
        except Exception as exc:
            logger.error(f"Failed to elevate privileges: {exc}")
            click.echo("❌ Failed to request administrator privileges.")
        sys.exit(0)


def get_hive_name(hive) -> str:
    """Convert registry hive constant to readable name."""
    hive_map = {
        winreg.HKEY_LOCAL_MACHINE: "HKLM",
        winreg.HKEY_CURRENT_USER: "HKCU",
        winreg.HKEY_USERS: "HKU",
        winreg.HKEY_CLASSES_ROOT: "HKCR"
    }
    return hive_map.get(hive, "UNKNOWN")


def safe_open_key(hive, path: str, access: int = winreg.KEY_READ) -> Optional[winreg.HKEYType]:
    """Safely open registry key with error handling."""
    try:
        return winreg.OpenKey(hive, path, 0, access)
    except FileNotFoundError:
        logger.debug(f"Key not found: {get_hive_name(hive)}\\{path}")
        return None
    except PermissionError:
        logger.warning(f"Permission denied: {get_hive_name(hive)}\\{path}")
        return None
    except Exception as exc:
        logger.error(f"Error opening {get_hive_name(hive)}\\{path}: {exc}")
        return None


def ends_with_ca7(name: str) -> bool:
    """
    Check if the key name ENDS with CA7 (case insensitive).
    Handles GUID format: {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXCA7}
    """
    clean_name = name.strip("{}").upper()
    return clean_name.endswith("CA7")


def get_subkeys(hive, path: str) -> List[Tuple[str, str]]:
    """Get all subkeys of a given registry key."""
    subkeys = []
    key = safe_open_key(hive, path)
    if not key:
        return subkeys
    
    try:
        index = 0
        while True:
            try:
                name = winreg.EnumKey(key, index)
                full_path = f"{path}\\{name}"
                subkeys.append((name, full_path))
                index += 1
            except OSError:
                break
    except Exception as exc:
        logger.error(f"Error enumerating subkeys of {path}: {exc}")
    finally:
        winreg.CloseKey(key)
    
    return subkeys


def scan_hku_for_ca7() -> List[Dict]:
    """
    Scan only HKU user hives for CLSID keys ending with CA7.
    Returns list of dictionaries with detailed info including subkeys.
    """
    findings = []
    
    click.echo("🔍 Scanning HKU for entries ENDING with CA7...\n")
    
    # Get all user SIDs
    user_sids = []
    key = safe_open_key(winreg.HKEY_USERS, "")
    if not key:
        click.echo("❌ Cannot access HKU")
        return findings
    
    try:
        index = 0
        while True:
            try:
                sid = winreg.EnumKey(key, index)
                # Only actual user SIDs (not system SIDs or _Classes)
                if sid.startswith("S-1-5-21") and "_Classes" not in sid:
                    user_sids.append(sid)
                index += 1
            except OSError:
                break
    except Exception as exc:
        logger.error(f"Error enumerating HKU: {exc}")
    finally:
        winreg.CloseKey(key)
    
    if not user_sids:
        click.echo("⚠️  No user SIDs found in HKU")
        return findings
    
    # Scan each user's Classes\Wow6432Node\CLSID
    for sid in user_sids:
        clsid_path = f"{sid}_Classes\\Wow6432Node\\CLSID"
        click.echo(f"📍 Scanning {sid}...")
        
        clsid_key = safe_open_key(winreg.HKEY_USERS, clsid_path)
        if not clsid_key:
            continue
        
        try:
            index = 0
            found_in_user = False
            while True:
                try:
                    subkey_name = winreg.EnumKey(clsid_key, index)
                    
                    # STRICT CHECK: Only if ENDS with CA7
                    if ends_with_ca7(subkey_name):
                        found_in_user = True
                        full_path = f"{clsid_path}\\{subkey_name}"
                        
                        # Get subkeys inside this CA7 entry
                        subkeys = get_subkeys(winreg.HKEY_USERS, full_path)
                        
                        finding = {
                            'hive': winreg.HKEY_USERS,
                            'sid': sid,
                            'clsid_path': clsid_path,
                            'full_path': full_path,
                            'name': subkey_name,
                            'subkeys': subkeys
                        }
                        findings.append(finding)
                        click.echo(f"   ✓ Found: {subkey_name}")
                        
                        # Show subkeys if any
                        if subkeys:
                            for sub_name, sub_path in subkeys:
                                click.echo(f"      └─ Subkey: {sub_name}")
                    
                    index += 1
                except OSError:
                    break
            
            if not found_in_user:
                click.echo(f"   (No CA7 entries found)")
                
        except Exception as exc:
            logger.error(f"Error scanning {clsid_path}: {exc}")
        finally:
            winreg.CloseKey(clsid_key)
    
    return findings


def display_findings(findings: List[Dict]) -> None:
    """Display formatted list of CA7 findings with subkeys."""
    if not findings:
        click.echo("\n❌ No registry entries ending with CA7 found in HKU.")
        return
    
    click.echo("\n" + "=" * 70)
    click.echo("         CA7 REGISTRY ENTRIES DETECTED (HKU ONLY)")
    click.echo("=" * 70)
    
    for idx, finding in enumerate(findings, 1):
        sid = finding['sid']
        name = finding['name']
        full_path = finding['full_path']
        
        # Extract just the relevant part for display
        display_path = full_path.replace(f"{sid}_Classes\\", "")
        
        click.echo(f"\n{idx}. Registry Hive: HKU")
        click.echo(f"   User SID:  {sid}")
        click.echo(f"   Full Path: HKU\\{full_path}")
        click.echo(f"   Key Name:  {name}")
        
        # Show last 10 chars ending
        clean_name = name.strip("{}")
        if len(clean_name) > 10:
            click.echo(f"   Ends With: ...{clean_name[-10:]}")
        
        # Show subkeys
        if finding['subkeys']:
            click.echo(f"   SubKeys ({len(finding['subkeys'])}):")
            for sub_name, sub_path in finding['subkeys']:
                click.echo(f"      • {sub_name}")
        else:
            click.echo(f"   SubKeys:   (none)")
    
    click.echo("\n" + "=" * 70)
    click.echo(f"Total entries found: {len(findings)}")
    click.echo("=" * 70)


def delete_registry_key_recursive(hive, key_path: str) -> bool:
    """Recursively delete registry key and all subkeys."""
    key = safe_open_key(hive, key_path, winreg.KEY_ALL_ACCESS)
    if not key:
        return False
    
    try:
        # Delete all subkeys first
        while True:
            try:
                subkey_name = winreg.EnumKey(key, 0)
                subkey_path = f"{key_path}\\{subkey_name}"
                if not delete_registry_key_recursive(hive, subkey_path):
                    return False
            except OSError:
                break
        
        winreg.CloseKey(key)
        key = None
        
        # Now delete this key
        winreg.DeleteKey(hive, key_path)
        logger.info(f"Successfully deleted: {key_path}")
        return True
        
    except PermissionError as exc:
        logger.error(f"Permission denied deleting {key_path}: {exc}")
        return False
    except Exception as exc:
        logger.error(f"Error deleting {key_path}: {exc}")
        return False
    finally:
        if key:
            try:
                winreg.CloseKey(key)
            except:
                pass


def backup_key(hive, path: str) -> Optional[str]:
    """Export registry key to temp file before deletion."""
    try:
        import tempfile
        import time
        
        hive_name = get_hive_name(hive)
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        backup_file = os.path.join(tempfile.gettempdir(), f"CA7_Backup_{hive_name}_{timestamp}.reg")
        
        full_path = f"{hive_name}\\{path}"
        result = os.system(f'reg export "{full_path}" "{backup_file}" /y >nul 2>&1')
        
        if result == 0:
            return backup_file
        return None
    except Exception as exc:
        logger.error(f"Backup failed: {exc}")
        return None


def perform_deletion(findings: List[Dict], force: bool) -> List[Tuple[str, bool]]:
    """Delete all found CA7 entries."""
    results = []
    
    if not findings:
        return results
    
    if not force:
        click.echo("\n⚠️  WARNING: This will PERMANENTLY delete the above entries!")
        click.echo("   This action CANNOT be undone!")
        if not click.confirm("❓ Do you want to proceed with deletion?", default=False):
            click.echo("\n❌ Operation cancelled.")
            return results
    
    click.echo("\n🚀 Starting deletion process...\n")
    
    for finding in findings:
        hive = finding['hive']
        path = finding['full_path']
        name = finding['name']
        sid = finding['sid']
        
        full_display = f"HKU\\{path}"
        
        click.echo(f"📍 Processing: {name}")
        click.echo(f"   User: {sid}")
        
        # Create backup
        backup_path = backup_key(hive, path)
        if backup_path:
            click.echo(f"   💾 Backup: {backup_path}")
        else:
            click.echo(f"   ⚠️  Backup failed, proceeding anyway...")
        
        # Perform deletion
        if delete_registry_key_recursive(hive, path):
            click.echo(f"   ✅ Successfully deleted\n")
            results.append((full_display, True))
        else:
            click.echo(f"   ❌ Failed to delete\n")
            results.append((full_display, False))
    
    return results


def show_summary(results: List[Tuple[str, bool]]) -> None:
    """Display final summary."""
    if not results:
        return
    
    click.echo("\n" + "=" * 70)
    click.echo("                    DELETION SUMMARY")
    click.echo("=" * 70)
    
    success = sum(1 for _, status in results if status)
    failed = len(results) - success
    
    click.echo(f"✅ Successfully deleted: {success}")
    click.echo(f"❌ Failed to delete:    {failed}")
    
    if failed > 0:
        click.echo("\nFailed entries:")
        for path, status in results:
            if not status:
                click.echo(f"   • {path}")
    
    if success == len(results) and success > 0:
        click.echo("\n🎉 All CA7 entries have been successfully removed!")
    
    click.echo("\n" + "=" * 70)


@click.command()
@click.option('--force', '-f', is_flag=True, help='Skip confirmation prompts')
@click.version_option(version="3.0.0")
def main(force):
    """
    🧹 CA7 Registry Cleaner v3.0 (HKU Only)
    
    Scans HKU user hives for CLSID entries ENDING with "CA7",
    displays them with subkeys, and optionally deletes them.
    """
    # Admin check
    if not is_admin():
        click.echo("🔐 Administrator privileges required!")
        click.echo("📢 Requesting elevation...")
        run_as_admin()
    
    # Main loop
    while True:
        click.clear()
        click.echo("=" * 70)
        click.echo("           CA7 REGISTRY CLEANER v3.0")
        click.echo("           (HKU Only - Ends with CA7)")
        click.echo("=" * 70)
        click.echo()
        click.echo("1. 🔍 Scan for CA7 entries")
        click.echo("2. 🗑️  Scan and Delete CA7 entries")
        click.echo("0. 🚪 Exit")
        click.echo()
        
        try:
            choice = click.prompt("Select option", type=int, default=0)
        except click.Abort:
            click.echo("\n👋 Goodbye!")
            sys.exit(0)
        
        if choice == 0:
            click.echo("👋 Goodbye!")
            sys.exit(0)
        
        elif choice == 1:
            # Scan only
            findings = scan_hku_for_ca7()
            display_findings(findings)
            
            click.echo("\nPress any key to return to menu...")
            click.getchar()
        
        elif choice == 2:
            # Scan and delete
            findings = scan_hku_for_ca7()
            display_findings(findings)
            
            if not findings:
                click.echo("\nPress any key to return to menu...")
                click.getchar()
                continue
            
            results = perform_deletion(findings, force)
            show_summary(results)
            
            click.echo("\nPress any key to return to menu...")
            click.getchar()
        
        else:
            click.echo("❌ Invalid option!")
            import time
            time.sleep(1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        click.echo("\n\n👋 Interrupted by user. Exiting.")
        sys.exit(0)
    except Exception as exc:
        logger.critical(f"Unhandled exception: {exc}", exc_info=True)
        click.echo(f"\n💥 Critical error: {exc}")
        sys.exit(1)