from cost_estimator import create_connection
from datetime import datetime, timezone

IDLE_MINUTES_THRESHOLD = 30  # Soglia di inattività in minuti

def has_attached_volumes(conn, instance_id):
    try:
        volume_attachments = list(conn.compute.volume_attachments(instance_id))
        print(f"→ Volumi attaccati: {len(volume_attachments)}")
        return len(volume_attachments) > 0
    except Exception as e:
        print(f"[WARN] Errore nel controllo volumi: {e}")
        return True  # Precauzione

def has_floating_ip(instance):
    try:
        for net in instance.addresses.values():
            for ip in net:
                ip_addr = ip.get('addr')
                ip_type = ip.get('OS-EXT-IPS:type')
                print(f"→ IP trovato: {ip_addr} (type: {ip_type})")
                if ip_type == 'floating':
                    return True
    except Exception as e:
        print(f"[WARN] Errore nel controllo IP: {e}")
        return True  # Precauzione
    return False

def detect_idle_instances():
    """
    Restituisce le VM considerate inattive.
    Debug incluso: stampa lo stato di ogni VM analizzata.
    """
    conn = create_connection()
    instances = conn.compute.servers(details=True)
    idle_vms = []
    now = datetime.now(timezone.utc)

    print("\n[DEBUG] Analisi delle VM in corso...\n")

    for instance in instances:
        print(f"\n--- VM {instance.name} ({instance.id}) ---")
        print(f"Status: {instance.status}")

        if instance.status == 'SHUTOFF':
            print("→ Saltata perché è spenta (SHUTOFF).")
            continue

        updated_at = getattr(instance, 'updated_at', None) or getattr(instance, 'created_at', None)
        if not updated_at:
            print("→ Nessun valore di updated_at disponibile.")
            continue

        try:
            updated_time = datetime.fromisoformat(updated_at.replace('Z', '+00:00'))
            minutes_since_update = (now - updated_time).total_seconds() / 60
            print(f"→ updated_at: {updated_time} ({minutes_since_update:.2f} minuti fa)")
        except ValueError:
            print(f"[WARN] Errore parsing updated_at per VM {instance.name}: {updated_at}")
            continue

        if minutes_since_update < IDLE_MINUTES_THRESHOLD:
            print("→ Attività recente: non considerata idle.")
            continue

        attached_volumes = has_attached_volumes(conn, instance.id)
        floating_ip = has_floating_ip(instance)

        if not attached_volumes and not floating_ip:
            print("→ *** Questa VM è considerata IDLE ***")
            idle_vms.append({
                "instance_name": instance.name,
                "id": instance.id,
                "status": instance.status,
                "hours_since_last_update": round(minutes_since_update / 60, 2)
            })
        else:
            print("→ Non è idle: ha volumi o floating IP.")

    print(f"\n[DEBUG] Totale VM IDLE trovate: {len(idle_vms)}\n")
    return idle_vms
