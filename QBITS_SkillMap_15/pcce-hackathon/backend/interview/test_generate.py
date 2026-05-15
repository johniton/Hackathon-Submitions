import requests, json

profile = {
    "name": "Harsh Gaonker",
    "summary": "Full stack dev",
    "experience": [{"title": "Dev", "company": "Tech", "bullets": ["Did stuff"]}]
}
res = requests.post("http://localhost:8002/resume/generate", data={
    "candidate_profile": json.dumps(profile),
    "template_name": "modern"
})
print(res.status_code)
print(list(res.json().keys()) if res.status_code == 200 else res.text)
