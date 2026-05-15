"""
Hustlr Resume Builder — GitHub Service
Fetch repos, user profile, build repo cards with stack detection.
Ported from ResumeForge lib/github/repo-card.ts
"""
import asyncio
import httpx
from typing import Optional


async def fetch_github_profile(username: str, token: Optional[str] = None) -> dict:
    """Fetch the GitHub user profile (name, bio, email, location, blog)."""
    headers = {"Accept": "application/vnd.github.v3+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.get(f"https://api.github.com/users/{username}", headers=headers)
        if resp.status_code != 200:
            return {}
        u = resp.json()
        return {
            "name": u.get("name") or u.get("login", ""),
            "email": u.get("email") or "",
            "location": u.get("location") or "",
            "bio": u.get("bio") or "",
            "blog": u.get("blog") or "",
            "avatar": u.get("avatar_url") or "",
            "github": u.get("html_url") or f"https://github.com/{username}",
            "public_repos": u.get("public_repos", 0),
            "followers": u.get("followers", 0),
        }


async def fetch_repos(github_url: str, token: Optional[str] = None) -> list:
    """Fetch all repos for a GitHub user. Supports PAT for private repos."""
    # Extract username from URL
    username = github_url.rstrip("/").split("/")[-1]
    if not username:
        raise ValueError("Invalid GitHub URL")

    headers = {"Accept": "application/vnd.github.v3+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    async with httpx.AsyncClient(timeout=30.0) as client:
        if token:
            url = "https://api.github.com/user/repos?sort=updated&per_page=100"
        else:
            url = f"https://api.github.com/users/{username}/repos?sort=updated&per_page=100"

        resp = await client.get(url, headers=headers)
        resp.raise_for_status()
        repos = resp.json()

    return [
        {
            "id": r["id"],
            "name": r["name"],
            "full_name": r["full_name"],
            "description": r.get("description") or "",
            "language": r.get("language") or "",
            "stars": r.get("stargazers_count", 0),
            "last_commit": r.get("updated_at", ""),
            "topics": r.get("topics", []),
            "url": r.get("html_url", ""),
            "private": r.get("private", False),
        }
        for r in repos
    ]


async def build_repo_card(owner: str, repo: str, token: Optional[str] = None) -> dict:
    """Build a compressed repo card with stack, README, commits."""
    headers = {"Accept": "application/vnd.github.v3+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    async with httpx.AsyncClient(timeout=30.0) as client:
        # Fetch repo info, commits, languages in parallel
        repo_url = f"https://api.github.com/repos/{owner}/{repo}"
        commits_url = f"{repo_url}/commits?per_page=5"
        langs_url = f"{repo_url}/languages"

        repo_resp, commits_resp, langs_resp = await asyncio.gather(
            client.get(repo_url, headers=headers),
            client.get(commits_url, headers=headers),
            client.get(langs_url, headers=headers),
            return_exceptions=True,
        )

        repo_info = repo_resp.json() if not isinstance(repo_resp, Exception) and repo_resp.status_code == 200 else {}
        commits = commits_resp.json() if not isinstance(commits_resp, Exception) and commits_resp.status_code == 200 else []
        languages = langs_resp.json() if not isinstance(langs_resp, Exception) and langs_resp.status_code == 200 else {}

        # Try README
        readme_excerpt = ""
        try:
            readme_resp = await client.get(f"{repo_url}/readme", headers=headers)
            if readme_resp.status_code == 200:
                import base64
                content = base64.b64decode(readme_resp.json().get("content", "")).decode("utf-8", errors="ignore")
                readme_excerpt = content[:2000]
        except Exception:
            readme_excerpt = repo_info.get("description", "")

        # Parse dependency files for stack detection
        stack = list(languages.keys()) if isinstance(languages, dict) else []
        dep_files = ["package.json", "requirements.txt", "go.mod", "Cargo.toml", "pyproject.toml"]
        for dep_file in dep_files:
            try:
                dep_resp = await client.get(f"{repo_url}/contents/{dep_file}", headers=headers)
                if dep_resp.status_code == 200:
                    import base64
                    content = base64.b64decode(dep_resp.json().get("content", "")).decode("utf-8", errors="ignore")
                    if dep_file == "package.json":
                        import json
                        pkg = json.loads(content)
                        deps = list((pkg.get("dependencies") or {}).keys()) + list((pkg.get("devDependencies") or {}).keys())
                        stack = list(set(stack + deps[:15]))
                    elif dep_file == "requirements.txt":
                        reqs = [l.split(">=")[0].split("==")[0].split("<")[0].strip() for l in content.split("\n") if l.strip() and not l.startswith("#")]
                        stack = list(set(stack + reqs[:15]))
                    break
            except Exception:
                continue

        commit_messages = []
        if isinstance(commits, list):
            commit_messages = [c.get("commit", {}).get("message", "").split("\n")[0] for c in commits[:5] if c.get("commit")]

        return {
            "name": repo_info.get("name", repo),
            "description": repo_info.get("description") or "",
            "url": repo_info.get("html_url", f"https://github.com/{owner}/{repo}"),
            "language": repo_info.get("language") or "",
            "stars": repo_info.get("stargazers_count", 0),
            "stack": stack[:20],
            "what_it_does": readme_excerpt.split("\n")[0] if readme_excerpt else repo_info.get("description", ""),
            "complexity_signals": commit_messages,
            "readme_excerpt": readme_excerpt[:500],
            "topics": repo_info.get("topics", []),
        }



def compress_repo_card(card: dict) -> str:
    """Compress a repo card for AI context."""
    import json
    return json.dumps({
        "name": card.get("name"),
        "description": card.get("description", "")[:200],
        "stack": card.get("stack", [])[:10],
        "what_it_does": card.get("what_it_does", "")[:200],
        "complexity_signals": card.get("complexity_signals", [])[:5],
        "stars": card.get("stars", 0),
        "topics": card.get("topics", [])[:8],
    })
