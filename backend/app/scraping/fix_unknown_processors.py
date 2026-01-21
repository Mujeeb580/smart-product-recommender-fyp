from app.core.firebase import firestore_db
from app.scraping.cleaner import extract_laptop_specs_from_name

def fix_unknown_processors():
    """Re-process laptops with Unknown processor using updated regex patterns"""
    try:
        print("=" * 80)
        print("FIXING UNKNOWN PROCESSORS")
        print("=" * 80)
        
        # Query laptops with processor = "Unknown"
        laptops_ref = firestore_db.collection('laptops')
        query = laptops_ref.where('processor', '==', 'Unknown')
        docs = query.stream()
        
        fixed_count = 0
        still_unknown = 0
        
        for doc in docs:
            data = doc.to_dict()
            name = data.get('name', '')
            
            # Try to extract processor from name using updated patterns
            extracted_specs = extract_laptop_specs_from_name(name)
            
            if 'processor' in extracted_specs:
                # Update the document
                doc_ref = firestore_db.collection('laptops').document(doc.id)
                update_data = {
                    'processor': extracted_specs['processor']
                }
                
                # Also update GPU if found
                if 'gpu' in extracted_specs:
                    update_data['gpu'] = extracted_specs['gpu']
                if 'gpu_memory' in extracted_specs:
                    update_data['gpu_memory'] = extracted_specs['gpu_memory']
                
                doc_ref.update(update_data)
                fixed_count += 1
                print(f"[FIXED] {name[:60]}")
                print(f"        Processor: {extracted_specs['processor']}")
            else:
                still_unknown += 1
                print(f"[STILL UNKNOWN] {name[:60]}")
        
        print(f"\n{'=' * 80}")
        print(f"✓ Fixed: {fixed_count}")
        print(f"✗ Still unknown: {still_unknown}")
        print(f"Total processed: {fixed_count + still_unknown}")
        print("=" * 80)
        
    except Exception as e:
        print(f"[ERROR] Failed to fix: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    fix_unknown_processors()
