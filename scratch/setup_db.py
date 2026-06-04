import sys
import subprocess
import time
import site

# Ensure user-site packages are in the python path
sys.path.append(site.getusersitepackages())

print("Checking database driver installation...")
try:
    import pg8000.dbapi
    print("pg8000 driver is already installed and loaded.")
except ImportError:
    print("pg8000 driver not found in path. Installing pg8000 pure-python Postgres driver...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pg8000", "--user"])
        # Reload sys.path with user site-packages again
        sys.path.append(site.getusersitepackages())
        import pg8000.dbapi
        print("pg8000 driver installed and loaded successfully!")
    except Exception as e:
        print(f"Error installing pg8000: {e}")
        sys.exit(1)

# Supabase Credentials
DB_HOST = "db.sbghojlespqzdelxrarh.supabase.co"
DB_PORT = 5432
DB_USER = "postgres"
DB_NAME = "postgres"
DB_PASS = "IHJyDFf95BrAca1a"

SQL_STATEMENTS = [
    # 1. Family Members Table
    """
    CREATE TABLE IF NOT EXISTS family_members (
        id UUID PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        role TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );
    """,
    # 2. Dishes Table
    """
    CREATE TABLE IF NOT EXISTS dishes (
        id UUID PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        tags TEXT[] NOT NULL,
        emoji TEXT NOT NULL,
        dish_description TEXT NOT NULL,
        ingredients TEXT[] NOT NULL,
        cook_note TEXT NOT NULL,
        is_favorite BOOLEAN NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );
    """,
    # 3. Meal Orders Table
    """
    CREATE TABLE IF NOT EXISTS meal_orders (
        id UUID PRIMARY KEY,
        member_id UUID REFERENCES family_members(id) ON DELETE CASCADE,
        dish_id UUID REFERENCES dishes(id) ON DELETE SET NULL,
        order_date TIMESTAMPTZ NOT NULL,
        note TEXT NOT NULL,
        is_fulfilled BOOLEAN NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );
    """
]

print("Connecting to Supabase cloud database...")
try:
    conn = pg8000.dbapi.connect(
        user=DB_USER,
        password=DB_PASS,
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME
    )
    cursor = conn.cursor()
    print("Successfully connected to the database!")
    
    for i, statement in enumerate(SQL_STATEMENTS, 1):
        print(f"Executing table creation statement {i}...")
        cursor.execute(statement)
        
    conn.commit()
    print("Database tables initialized successfully! All tables created!")
    
    cursor.close()
    conn.close()
    print("Connection closed. Cloud setup completed!")
    
except Exception as e:
    print(f"Error connecting or executing SQL in Supabase: {e}")
    sys.exit(1)
