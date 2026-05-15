# Project Name
SkillMap
## Team Name
QBITS
## Problem Statement
#15 – SkillMap: AI-Powered Skill Gap Detector & Career Readiness Engine
Problem Context 
Millions of students and job seekers in India apply to opportunities they are either overqualified or underprepared for — not out of ignorance, but because no accessible tool exists to objectively map their current profile against real market requirements. Job descriptions are written in inconsistent formats, skill expectations vary wildly across companies, and free learning resources are abundant but completely unnavigated. Career counselors are expensive and scarce outside metro cities. The result is a massive mismatch — talented individuals stuck in wrong roles or unemployed, while companies struggle to find job-ready candidates despite a surplus of graduates.
Challenge 
Build an intelligent skill gap detection and career readiness platform that takes a user's current profile — resume, self-assessed skills, certifications, projects — and compares it against a target job posting or career path. The system should identify exact missing skills, rank them by criticality, and generate a personalized, time-bound preparation roadmap with curated free resources. Features such as resume scoring against a specific job description, mock interview question generation based on identified gaps, peer benchmarking against others targeting the same role, and progress tracking over time can make this a comprehensive career acceleration tool rather than a one-time gap report.
## Team Members
- Johniton Mascarenhas
- Ankur Kunde
- Harsh Gaonker
- Shreya Upadhayay

## GitHub Repository
https://github.com/johniton/hustlr.git

## Demo Video
https://youtu.be/07hdUc7fzw4?si=I3VyofwjvWl69LFq

## Presentation Link
https://drive.google.com/file/d/1ArRSYVB3ui5poQdOM-pwHwkgSiSDGDdR/view?usp=sharing
## Features
- AI-Powered Mock Interviews: Realistic interview simulations with dynamic follow-up questions and performance analytics (clarity, confidence, and relevance scoring).
- Intelligent Resume Builder: Multi-source import (LinkedIn, GitHub), ATS compatibility scoring, and real-time keyword optimization with PDF/DOCX export.
- Skill Assessment & Roadmaps: Skills gap analysis that generates personalized learning paths and interactive roadmaps to address career deficiencies.
- Peer-to-Peer Skill Swap: A matching algorithm that connects users to exchange skills, manage sessions, and verify practical learning.
- Job Discovery Engine: Location-based job search with company research tools and application tracking.
- Professional Community: Social feed with XP bars, skill-based challenges, leaderboards, and a digital certificate vault.
- Interactive Flashcards: Gamified learning modules with "tap to flip" interactive decks for quick skill reinforcement.


## Tech Stack
- Frontend: Flutter (Mobile - iOS/Android)
- Backend: FastAPI (Python)
- Database: Supabase (PostgreSQL)
- AI/ML:
- LLMs: Groq (Llama-3 models) for question generation and resume analysis.
- Search: Tavily API for real-time company research.
- Processing: FFmpeg & OpenCV for video/speech analysis, PyTesseract for OCR.


## Setup Instructions
1. Backend Setup
Navigate to the backend directory:

bash
cd backend/interview

Create and activate a virtual environment:

bash
python -m venv .venv
source .venv/bin/activate  # On Windows use .venv\Scripts\activate

Install the required dependencies:
bash
pip install -r requirements.txt
Configure the .env file with your SUPABASE_URL, SUPABASE_KEY, and GROQ_API_KEY.

Start the FastAPI server:
bash
uvicorn app.main:app --reload

2. Frontend Setup

Navigate to the frontend directory:
bash
cd frontend/hustlr

Install Flutter dependencies:
bash
flutter pub get
Ensure your mobile emulator or device is connected.

Run the application:
bash
flutter run
