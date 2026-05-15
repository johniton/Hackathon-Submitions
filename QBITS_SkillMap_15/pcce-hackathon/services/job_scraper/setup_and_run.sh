#!/bin/bash

# Exit on any error
set -e

echo "🚀 Starting Job Scraper Setup..."

# Navigate to the script's directory so it can be run from anywhere
cd "$(dirname "$0")"

# 1. Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install it to continue."
    exit 1
fi

# 2. Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment (venv)..."
    python3 -m venv venv
else
    echo "✅ Virtual environment already exists."
fi

# 3. Activate virtual environment
echo "🔄 Activating virtual environment..."
source venv/bin/activate

# 4. Install requirements
echo "📥 Installing dependencies from requirements.txt..."
pip install --upgrade pip
pip install -r requirements.txt

# 5. Handle .env file
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo "📝 Creating .env from .env.example..."
        cp .env.example .env
        echo "⚠️ NOTE: Please update the .env file with your LinkedIn credentials if you want authenticated scraping."
    else
        echo "❌ .env.example not found!"
    fi
else
    echo "✅ .env file already exists."
fi

# 6. Playwright browsers
# Since you already have chromium installed, we skip this by default but leave the command here just in case.
# playwright install chromium

echo "✨ Setup complete!"
echo "🚀 Starting FastAPI server on http://0.0.0.0:8001..."

# 7. Run the server
uvicorn main:app --reload --host 0.0.0.0 --port 8001
