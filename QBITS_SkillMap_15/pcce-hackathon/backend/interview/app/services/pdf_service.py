"""
Hustlr Resume Builder — PDF Service (v2)
Renders resume JSON into production-quality HTML templates, then converts to PDF via weasyprint.
Each template uses a section-injection model — the service builds HTML fragments
for each resume section and injects them into the template's placeholder slots.
"""
import os
from typing import Optional


TEMPLATES_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "templates")

AVAILABLE_TEMPLATES = ["ats_safe", "creative", "academic", "fresher", "minimal", "classic", "executive", "modern", "tech", "bold"]


def _load_template(template_name: str) -> str:
    """Load an HTML template file."""
    name = template_name if template_name in AVAILABLE_TEMPLATES else "ats_safe"
    path = os.path.join(TEMPLATES_DIR, f"{name}.html")
    with open(path, "r") as f:
        return f.read()


# ═══════════════════════════════════════════════════════════════
# Section Renderers — produce HTML fragments for each section
# ═══════════════════════════════════════════════════════════════

def _render_contact_line(r: dict) -> str:
    """Build a single-line contact string."""
    parts = []
    if r.get("email"):
        parts.append(r["email"])
    if r.get("phone"):
        parts.append(r["phone"])
    if r.get("location"):
        parts.append(r["location"])
    if r.get("linkedin"):
        parts.append(f'<a href="{r["linkedin"]}">{r["linkedin"]}</a>')
    if r.get("github"):
        parts.append(f'<a href="{r["github"]}">{r["github"]}</a>')
    return " &nbsp;|&nbsp; ".join(parts)


def _render_contact_block(r: dict) -> str:
    """Build multi-line contact block (for creative template right-aligned)."""
    lines = []
    if r.get("phone"):
        lines.append(f"<div>{r['phone']}</div>")
    if r.get("email"):
        lines.append(f'<div><a href="mailto:{r["email"]}">{r["email"]}</a></div>')
    if r.get("github"):
        lines.append(f'<div><a href="{r["github"]}">{r["github"]}</a></div>')
    if r.get("linkedin"):
        lines.append(f'<div><a href="{r["linkedin"]}">{r["linkedin"]}</a></div>')
    if r.get("location"):
        lines.append(f"<div>{r['location']}</div>")
    return "\n".join(lines)


def _render_contact_for_ats(r: dict) -> str:
    """Build contact info line for ATS template."""
    parts = []
    if r.get("email"):
        parts.append(f'<span class="email">Email: </span><span class="email-val">{r["email"]}</span>')
    if r.get("phone"):
        parts.append(f'<span class="phone">Phone: </span><span class="phone-val">{r["phone"]}</span>')
    if r.get("location"):
        parts.append(f'<span>{r["location"]}</span>')
    if r.get("linkedin"):
        parts.append(f'<a href="{r["linkedin"]}">LinkedIn</a>')
    if r.get("github"):
        parts.append(f'<a href="{r["github"]}">GitHub</a>')
    return '<span class="separator"></span>'.join(parts)


def _section_wrap_ats(title: str, content: str) -> str:
    """Wrap content in ATS template section."""
    if not content.strip():
        return ""
    return f'<div class="section"><div class="section__title">{title}</div><div class="section__list">{content}</div></div>'


def _section_wrap_creative(title: str, content: str) -> str:
    """Wrap content in Creative template section."""
    if not content.strip():
        return ""
    return f'<div class="section row"><h2 class="col">{title}</h2><div class="section-text col-right">{content}</div></div>'


def _section_wrap_generic(title: str, content: str, divider: bool = False) -> str:
    """Wrap content in standard section."""
    if not content.strip():
        return ""
    div = '<div class="divider"></div>' if divider else ""
    return f'<div class="section"><div class="section-title">{title}</div>{div}{content}</div>'


def _section_wrap_executive(title: str, content: str) -> str:
    """Wrap content in Executive template section (sidebar label + content)."""
    if not content.strip():
        return ""
    return f'<div class="section"><div class="section-label"><h2>{title}</h2></div><div class="section-content">{content}</div></div>'


# ─── Experience ───────────────────────────────────────────────

def _render_experience_ats(experience: list) -> str:
    parts = []
    for exp in experience:
        bullets = ""
        if isinstance(exp.get("bullets"), list) and exp["bullets"]:
            bullets = "<ul>" + "".join(f"<li>{b}</li>" for b in exp["bullets"]) + "</ul>"
        parts.append(f'''<div class="section__list-item">
  <div class="left">
    <div class="name">{exp.get('company', '')}</div>
    <div class="addr">{exp.get('location', '')}</div>
    <div class="duration">{exp.get('dates', '')}</div>
  </div>
  <div class="right">
    <div class="name">{exp.get('title', '')}</div>
    <div class="desc">{bullets}</div>
  </div>
</div>''')
    return _section_wrap_ats("Experience", "\n".join(parts))


def _render_experience_creative(experience: list) -> str:
    parts = []
    for exp in experience:
        bullets = ""
        if isinstance(exp.get("bullets"), list) and exp["bullets"]:
            bullets = "<ul class='desc'>" + "".join(f"<li>{b}</li>" for b in exp["bullets"]) + "</ul>"
        parts.append(f'''<div class="section-text col-right">
  <div class="row"><div class="col"><h3>{exp.get('company', '')}</h3></div></div>
  <div class="row subsection">
    <div class="emph col">{exp.get('title', '')}</div>
    <div class="col-right light">{exp.get('dates', '')}</div>
  </div>
  {bullets}
</div>''')
    return _section_wrap_creative("Experience", "\n".join(parts))


def _render_experience_generic(experience: list) -> str:
    parts = []
    for exp in experience:
        bullets = ""
        if isinstance(exp.get("bullets"), list) and exp["bullets"]:
            bullets = '<ul class="bullets">' + "".join(f"<li>{b}</li>" for b in exp["bullets"]) + "</ul>"
        parts.append(f'''<div class="entry">
  <div class="entry-head">
    <div><span class="entry-title">{exp.get('title', '')}</span> — {exp.get('company', '')}</div>
    <div class="entry-date">{exp.get('dates', '')}</div>
  </div>
  {f'<div class="entry-sub">{exp.get("location", "")}</div>' if exp.get("location") else ""}
  {bullets}
</div>''')
    return "\n".join(parts)


# ─── Education ────────────────────────────────────────────────

def _render_education_ats(education: list) -> str:
    parts = []
    for edu in education:
        gpa = f" | GPA: {edu['gpa']}" if edu.get("gpa") else ""
        parts.append(f'''<div class="section__list-item">
  <div class="left">
    <div class="name">{edu.get('school', '')}</div>
    <div class="duration">{edu.get('dates', '')}</div>
  </div>
  <div class="right">
    <div class="name">{edu.get('degree', '')}</div>
    <div class="desc">{gpa}</div>
  </div>
</div>''')
    return _section_wrap_ats("Education", "\n".join(parts))


def _render_education_creative(education: list) -> str:
    parts = []
    for edu in education:
        gpa = f" — GPA: {edu['gpa']}" if edu.get("gpa") else ""
        parts.append(f'''<div class="section-text col-right">
  <h3><span class="emph">{edu.get('degree', '')}</span>{gpa}</h3>
  <div>{edu.get('school', '')}</div>
  <div class="row">
    <div class="col light">{edu.get('location', '')}</div>
    <div class="col-right light">{edu.get('dates', '')}</div>
  </div>
</div>''')
    return _section_wrap_creative("Education", "\n".join(parts))


def _render_education_generic(education: list) -> str:
    parts = []
    for edu in education:
        gpa = f" | GPA: {edu['gpa']}" if edu.get("gpa") else ""
        parts.append(f'''<div class="entry">
  <div class="entry-head">
    <div class="entry-title">{edu.get('school', '')}</div>
    <div class="entry-date">{edu.get('dates', '')}</div>
  </div>
  <div class="entry-sub">{edu.get('degree', '')}{gpa}</div>
</div>''')
    return "\n".join(parts)


# ─── Projects ────────────────────────────────────────────────

def _render_projects_ats(projects: list) -> str:
    parts = []
    for proj in projects:
        stack = f' <span class="tech-stack">({", ".join(proj["stack"])})</span>' if proj.get("stack") else ""
        url = f' — <a href="{proj["url"]}">{proj["url"]}</a>' if proj.get("url") else ""
        parts.append(f'''<div class="section__list-item">
  <div class="name">{proj.get('name', '')}{url}</div>
  <div class="text">{proj.get('description', '')}{stack}</div>
</div>''')
    return _section_wrap_ats("Projects", "\n".join(parts))


def _render_projects_generic(projects: list) -> str:
    parts = []
    for proj in projects:
        stack = ""
        if proj.get("stack"):
            stack = '<div class="tech-stack">' + " ".join(f'<span class="chip">{s}</span>' for s in proj["stack"]) + "</div>"
        url = f' — <a href="{proj["url"]}">{proj["url"]}</a>' if proj.get("url") else ""
        parts.append(f'''<div class="entry">
  <div class="entry-head">
    <div class="entry-title">{proj.get('name', '')}{url}</div>
  </div>
  <div class="entry-desc">{proj.get('description', '')}</div>
  {stack}
</div>''')
    return "\n".join(parts)


# ─── Skills ──────────────────────────────────────────────────

def _render_skills_ats(skills) -> str:
    if isinstance(skills, dict):
        items = []
        for cat, items_list in skills.items():
            if isinstance(items_list, list) and items_list:
                label = cat.replace("_", " ").title()
                dots = " ".join(f'<span class="chip">{s}</span>' for s in items_list)
                items.append(f'<div class="skills__item"><div class="left"><div class="name">{label}</div></div><div class="right">{dots}</div></div>')
        return _section_wrap_ats("Skills", "\n".join(items))
    elif isinstance(skills, list):
        chips = " ".join(f'<span class="chip">{s}</span>' for s in skills)
        return _section_wrap_ats("Skills", chips)
    return ""


def _render_skills_creative(skills) -> str:
    if isinstance(skills, dict):
        all_skills = []
        for items_list in skills.values():
            if isinstance(items_list, list):
                all_skills.extend(items_list)
        keys = " ".join(f'<span class="key">{s}</span>' for s in all_skills[:20])
        return _section_wrap_creative("Skills", keys)
    elif isinstance(skills, list):
        keys = " ".join(f'<span class="key">{s}</span>' for s in skills[:20])
        return _section_wrap_creative("Skills", keys)
    return ""


def _render_skills_generic(skills) -> str:
    if isinstance(skills, dict):
        groups = []
        for cat, items_list in skills.items():
            if isinstance(items_list, list) and items_list:
                label = cat.replace("_", " ").title()
                chips = " ".join(f'<span class="chip">{s}</span>' for s in items_list)
                groups.append(f'<div class="skill-group"><span class="skill-label">{label}: </span>{chips}</div>')
        return "\n".join(groups)
    elif isinstance(skills, list):
        return " ".join(f'<span class="chip">{s}</span>' for s in skills)
    return ""


# ─── Certifications ──────────────────────────────────────────

def _render_certs(certs: list) -> str:
    if not certs:
        return ""
    parts = []
    for c in certs:
        date_str = f" ({c['date']})" if c.get("date") else ""
        issuer_str = f" — {c['issuer']}" if c.get("issuer") else ""
        parts.append(f"<li>{c.get('name', '')}{issuer_str}{date_str}</li>")
    return "<ul>" + "".join(parts) + "</ul>"


# ─── Achievements ────────────────────────────────────────────

def _render_achievements(achievements: list) -> str:
    if not achievements:
        return ""
    return "<ul>" + "".join(f"<li>{a}</li>" for a in achievements) + "</ul>"


# ─── Executive Template Renderers ────────────────────────────

def _render_experience_executive(experience: list) -> str:
    parts = []
    for exp in experience:
        bullets = ""
        if isinstance(exp.get("bullets"), list) and exp["bullets"]:
            bullets = "<ul>" + "".join(f"<li>{b}</li>" for b in exp["bullets"]) + "</ul>"
        loc = f'<div class="entry-loc">{exp.get("location", "")}</div>' if exp.get("location") else ""
        parts.append(f'''<div class="entry">
  <div class="entry-header">
    <h3>{exp.get('company', '')}</h3>
    <span class="entry-date">{exp.get('dates', '')}</span>
  </div>
  <div class="entry-role">{exp.get('title', '')}</div>
  {loc}
  <div class="entry-desc">{bullets}</div>
</div>''')
    return _section_wrap_executive("Experience", "\n".join(parts))


def _render_education_executive(education: list) -> str:
    parts = []
    for edu in education:
        gpa = f" — GPA: {edu['gpa']}" if edu.get("gpa") else ""
        parts.append(f'''<div class="entry">
  <h3>{edu.get('school', '')}</h3>
  <div class="entry-role">{edu.get('degree', '')}{gpa}</div>
  <div class="entry-header">
    <span class="entry-loc">{edu.get('location', '')}</span>
    <span class="entry-date">{edu.get('dates', '')}</span>
  </div>
</div>''')
    return _section_wrap_executive("Education", "\n".join(parts))


def _render_skills_executive(skills) -> str:
    if isinstance(skills, dict):
        all_skills = []
        for items_list in skills.values():
            if isinstance(items_list, list):
                all_skills.extend(items_list)
        keys = " ".join(f'<span class="key">{s}</span>' for s in all_skills[:25])
        return _section_wrap_executive("Skills", keys)
    elif isinstance(skills, list):
        keys = " ".join(f'<span class="key">{s}</span>' for s in skills[:25])
        return _section_wrap_executive("Skills", keys)
    return ""


def _render_projects_executive(projects: list) -> str:
    parts = []
    for proj in projects:
        stack = f' <span class="desc">({"    , ".join(proj["stack"])})</span>' if proj.get("stack") else ""
        url = f' — <a href="{proj["url"]}">{proj["url"]}</a>' if proj.get("url") else ""
        parts.append(f'<div class="entry"><h3>{proj.get("name", "")}{url}</h3>{stack}<div class="desc">{proj.get("description", "")}</div></div>')
    return _section_wrap_executive("Projects", "\n".join(parts))


# ─── MODERN TEMPLATE (two-column: sidebar + main) ─────────────
def _render_modern_sidebar_skill(skills) -> str:
    skill_groups = []
    if isinstance(skills, dict):
        for cat, items_list in skills.items():
            if isinstance(items_list, list) and items_list:
                tags = "".join(f'<span class="side-skill-tag">{s}</span>' for s in items_list)
                skill_groups.append(f'<div class="skill-group"><div class="side-section-title" style="margin-top:3mm">{cat.replace("_"," ").title()}</div>{tags}</div>')
        return "\n".join(skill_groups)
    elif isinstance(skills, list):
        tags = "".join(f'<span class="side-skill-tag">{s}</span>' for s in skills)
        return tags
    return ""


def _render_modern_sidebar_certs(certs: list) -> str:
    if not certs:
        return ""
    return "\n".join(f'<div class="side-cert"><div class="side-cert-name">{c.get("name","")}</div><div class="side-cert-issuer">{c.get("issuer","")}</div><div class="side-cert-date">{c.get("date","")}</div></div>' for c in certs)


def _render_modern_sidebar_ach(achievements: list) -> str:
    if not achievements:
        return ""
    return "\n".join(f'<div class="side-ach-item">{a}</div>' for a in achievements)


def _render_modern_main(experience, education, projects) -> str:
    parts = []

    # Summary
    if r.get("summary"):
        parts.append(f'<div class="main-section"><div class="main-headline">{r.get("headline","")}</div><div class="main-summary">{r.get("summary","")}</div></div>')

    # Experience
    if experience:
        parts.append('<div class="main-section"><div class="main-section-title">Experience</div>')
        for exp in experience:
            bullets = ""
            if isinstance(exp.get("bullets"), list) and exp["bullets"]:
                bullets = "<ul class='exp-bullets'>" + "".join(f"<li>{b}</li>" for b in exp["bullets"]) + "</ul>"
            parts.append(f'<div class="exp-item"><div class="exp-header"><span class="exp-company">{exp.get("company","")}</span><span class="exp-dates">{exp.get("dates","")}</span></div><div class="exp-title">{exp.get("title","")}</div>{bullets}</div>')
        parts.append('</div>')

    # Education
    if education:
        parts.append('<div class="main-section"><div class="main-section-title">Education</div>')
        for edu in education:
            gpa = f' | GPA: {edu.get("gpa","")}' if edu.get("gpa") else ""
            parts.append(f'<div class="edu-item"><div class="edu-header"><span class="edu-school">{edu.get("school","")}</span><span class="edu-dates">{edu.get("dates","")}</span></div><div class="edu-degree">{edu.get("degree","")}{gpa}</div></div>')
        parts.append('</div>')

    # Projects
    if projects:
        parts.append('<div class="main-section"><div class="main-section-title">Projects</div>')
        for p in projects:
            stack = f'<span class="proj-stack"> — {", ".join(p["stack"])}</span>' if p.get("stack") else ""
            url = f' <span class="proj-url">{p.get("url","")}</span>' if p.get("url") else ""
            parts.append(f'<div class="proj-item"><div class="proj-name">{p.get("name","")}{stack}</div><div class="proj-desc">{p.get("description","")}{url}</div></div>')
        parts.append('</div>')

    return "\n".join(parts)


# ─── TECH TEMPLATE (dark sidebar + main) ─────────────────────
def _render_tech_sidebar_skill(skills) -> str:
    if isinstance(skills, dict):
        all_s = []
        for items_list in skills.values():
            if isinstance(items_list, list):
                all_s.extend(items_list)
        groups = []
        for i in range(0, len(all_s), 5):
            chunk = all_s[i:i+5]
            dots = "".join(f'<div class="dot filled"></div>' for _ in chunk)
            groups.append(f'<div class="skill-bar"><div class="skill-name">{", ".join(chunk)}</div><div class="skill-dots">{dots}</div></div>')
        return "".join(groups)
    elif isinstance(skills, list):
        chunks = [skills[i:i+4] for i in range(0, len(skills), 4)]
        groups = []
        for chunk in chunks:
            dots = "".join(f'<div class="dot filled"></div>' for _ in chunk)
            groups.append(f'<div class="skill-bar"><div class="skill-name">{", ".join(chunk)}</div><div class="skill-dots">{dots}</div></div>')
        return "".join(groups)
    return ""


def _render_tech_sidebar_certs(certs: list) -> str:
    if not certs:
        return ""
    return "\n".join(f'<div class="cert-item"><div class="cert-name">// {c.get("name","")}</div><div class="cert-meta">{c.get("issuer","")} | {c.get("date","")}</div></div>' for c in certs)


def _render_tech_sidebar_ach(achievements: list) -> str:
    if not achievements:
        return ""
    return "\n".join(f'<div class="ach-tag">{a}</div>' for a in achievements)


def _render_tech_main(experience, education, projects) -> str:
    parts = []

    if r.get("summary"):
        parts.append(f'<div class="main-headline">{r.get("headline","")}</div><div class="main-summary">{r.get("summary","")}</div>')

    if experience:
        parts.append('<div class="section"><div class="section-title">// EXPERIENCE</div>')
        for exp in experience:
            bullets = ""
            if isinstance(exp.get("bullets"), list) and exp["bullets"]:
                bullets = "<ul class='exp-bullets'>" + "".join(f"<li>{b}</li>" for b in exp["bullets"]) + "</ul>"
            parts.append(f'<div class="exp-item"><div class="exp-header"><span class="exp-company">{exp.get("company","")}</span><span class="exp-dates">{exp.get("dates","")}</span></div><div class="exp-title">{exp.get("title","")}</div>{bullets}</div>')
        parts.append('</div>')

    if education:
        parts.append('<div class="section"><div class="section-title">// EDUCATION</div>')
        for edu in education:
            parts.append(f'<div class="edu-item"><span class="edu-school">{edu.get("school","")}</span> <span class="edu-degree">{edu.get("degree","")}</span> <span class="edu-dates">{edu.get("dates","")}</span></div>')
        parts.append('</div>')

    if projects:
        parts.append('<div class="section"><div class="section-title">// PROJECTS</div>')
        for p in projects:
            stack = f' <span class="proj-stack">[{", ".join(p["stack"])}]</span>' if p.get("stack") else ""
            parts.append(f'<div class="proj-item"><div class="proj-name">{p.get("name","")}{stack}</div><div class="proj-desc">{p.get("description","")}</div></div>')
        parts.append('</div>')

    return "\n".join(parts)


# ─── BOLD TEMPLATE ───────────────────────────────────────────
def _render_bold_contact_bar(r: dict) -> str:
    items = []
    if r.get("email"):
        items.append(f'<div class="contact-item"><a href="mailto:{r["email"]}">{r["email"]}</a></div>')
    if r.get("phone"):
        items.append(f'<div class="contact-item">{r["phone"]}</div>')
    if r.get("location"):
        items.append(f'<div class="contact-item">{r["location"]}</div>')
    if r.get("linkedin"):
        items.append(f'<div class="contact-item"><a href="{r["linkedin"]}">LinkedIn</a></div>')
    if r.get("github"):
        items.append(f'<div class="contact-item"><a href="{r["github"]}">GitHub</a></div>')
    return "".join(items)


def _render_bold_main(experience, education, projects, skills, certs, achievements) -> str:
    parts = []

    if r.get("summary"):
        parts.append(f'<div class="body-section"><div class="body-section-title">Profile</div><div class="summary-text">{r.get("summary","")}</div></div>')

    if experience:
        parts.append('<div class="body-section"><div class="body-section-title">Experience</div>')
        for exp in experience:
            bullets = ""
            if isinstance(exp.get("bullets"), list) and exp["bullets"]:
                bullets = "<ul class='exp-bullets'>" + "".join(f"<li>{b}</li>" for b in exp["bullets"]) + "</ul>"
            loc = f'<div class="exp-loc" style="font-size:7.5pt;color:#888;margin-bottom:0.5mm">{exp.get("location","")}</div>' if exp.get("location") else ""
            parts.append(f'<div class="exp-item"><div class="exp-header"><span class="exp-company">{exp.get("company","")}</span><span class="exp-dates">{exp.get("dates","")}</span></div><div class="exp-title">{exp.get("title","")}</div>{loc}{bullets}</div>')
        parts.append('</div>')

    if education:
        parts.append('<div class="body-section"><div class="body-section-title">Education</div>')
        for edu in education:
            gpa = f' | GPA: {edu.get("gpa","")}' if edu.get("gpa") else ""
            parts.append(f'<div class="edu-item"><div class="edu-header"><span class="edu-school">{edu.get("school","")}</span><span class="edu-dates">{edu.get("dates","")}</span></div><div class="edu-degree">{edu.get("degree","")}{gpa}</div></div>')
        parts.append('</div>')

    if projects:
        parts.append('<div class="body-section"><div class="body-section-title">Projects</div>')
        for p in projects:
            stack = f'<div class="proj-stack">Stack: {", ".join(p["stack"])}</div>' if p.get("stack") else ""
            url = f'<div class="proj-url">{p.get("url","")}</div>' if p.get("url") else ""
            parts.append(f'<div class="proj-item"><div class="proj-name">{p.get("name","")}</div>{stack}<div class="proj-desc">{p.get("description","")}</div>{url}</div>')
        parts.append('</div>')

    if skills:
        parts.append('<div class="body-section"><div class="body-section-title">Skills</div>')
        if isinstance(skills, dict):
            for cat, items_list in skills.items():
                if isinstance(items_list, list) and items_list:
                    pills = "".join(f'<span class="skill-pill">{s}</span>' for s in items_list)
                    parts.append(f'<div class="skill-row"><div class="skill-category">{cat.replace("_"," ").title()}</div>{pills}</div>')
        elif isinstance(skills, list):
            pills = "".join(f'<span class="skill-pill">{s}</span>' for s in skills)
            parts.append(pills)
        parts.append('</div>')

    if certs:
        parts.append('<div class="body-section"><div class="body-section-title">Certifications</div>')
        for c in certs:
            parts.append(f'<div class="cert-item"><div class="cert-name">{c.get("name","")}</div><div class="cert-meta">{c.get("issuer","")} — {c.get("date","")}</div></div>')
        parts.append('</div>')

    if achievements:
        parts.append('<div class="body-section"><div class="body-section-title">Achievements</div>')
        for a in achievements:
            parts.append(f'<div class="ach-item">{a}</div>')
        parts.append('</div>')

    return "\n".join(parts)


# ═══════════════════════════════════════════════════════════════
# Main Renderer
# ═══════════════════════════════════════════════════════════════

def render_resume_html(resume_json: dict, template_name: str = "ats_safe") -> str:
    """Render resume JSON into a complete HTML page using the selected template."""
    global r
    r = resume_json
    template = _load_template(template_name)

    # Split name into first/last for ATS template
    name = r.get("name", "")
    name_parts = name.split(" ", 1)
    first_name = name_parts[0] if name_parts else ""
    last_name = name_parts[1] if len(name_parts) > 1 else ""

    experience = r.get("experience", []) or []
    education = r.get("education", []) or []
    projects = r.get("projects", []) or []
    skills = r.get("skills", {}) or {}
    certs = r.get("certifications", []) or []
    achievements = r.get("achievements", []) or []

    # ── ATS SAFE TEMPLATE ──
    if template_name == "ats_safe":
        html = template
        html = html.replace("{{FIRST_NAME}}", first_name)
        html = html.replace("{{LAST_NAME}}", last_name)
        html = html.replace("{{CONTACT_LINE}}", _render_contact_for_ats(r))
        html = html.replace("{{HEADLINE}}", r.get("headline", ""))
        html = html.replace("{{SUMMARY}}", r.get("summary", ""))
        html = html.replace("{{EXPERIENCE_SECTION}}", _render_experience_ats(experience))
        html = html.replace("{{EDUCATION_SECTION}}", _render_education_ats(education))
        html = html.replace("{{PROJECTS_SECTION}}", _render_projects_ats(projects))
        html = html.replace("{{SKILLS_SECTION}}", _render_skills_ats(skills))
        html = html.replace("{{CERTIFICATIONS_SECTION}}", _section_wrap_ats("Certifications", _render_certs(certs)))
        html = html.replace("{{ACHIEVEMENTS_SECTION}}", _section_wrap_ats("Achievements & Interests", _render_achievements(achievements)))
        return html

    # ── CREATIVE TEMPLATE ──
    elif template_name == "creative":
        html = template
        html = html.replace("{{NAME}}", name)
        html = html.replace("{{CONTACT_BLOCK}}", _render_contact_block(r))
        summary_section = _section_wrap_creative("Summary", f"<div>{r.get('summary', '')}</div>") if r.get("summary") else ""
        html = html.replace("{{SUMMARY_SECTION}}", summary_section)
        html = html.replace("{{SKILLS_SECTION}}", _render_skills_creative(skills))
        html = html.replace("{{EXPERIENCE_SECTION}}", _render_experience_creative(experience))
        html = html.replace("{{EDUCATION_SECTION}}", _render_education_creative(education))

        # Projects for creative
        proj_parts = []
        for p in projects:
            stack = f' <span class="desc">({", ".join(p["stack"])})</span>' if p.get("stack") else ""
            proj_parts.append(f'<div class="section-text col-right"><h3>{p.get("name", "")}{stack}</h3><div class="desc">{p.get("description", "")}</div></div>')
        html = html.replace("{{PROJECTS_SECTION}}", _section_wrap_creative("Projects", "\n".join(proj_parts)))
        html = html.replace("{{CERTIFICATIONS_SECTION}}", _section_wrap_creative("Certifications", _render_certs(certs)))
        html = html.replace("{{ACHIEVEMENTS_SECTION}}", _section_wrap_creative("Honors", _render_achievements(achievements)))
        return html

    # ── CLASSIC TEMPLATE (uses ATS-style wrappers with centered header) ──
    elif template_name == "classic":
        html = template
        html = html.replace("{{FIRST_NAME}}", first_name)
        html = html.replace("{{LAST_NAME}}", last_name)
        html = html.replace("{{CONTACT_LINE}}", _render_contact_for_ats(r))
        html = html.replace("{{HEADLINE}}", r.get("headline", ""))
        html = html.replace("{{SUMMARY}}", r.get("summary", ""))
        html = html.replace("{{EXPERIENCE_SECTION}}", _render_experience_ats(experience))
        html = html.replace("{{EDUCATION_SECTION}}", _render_education_ats(education))
        html = html.replace("{{PROJECTS_SECTION}}", _render_projects_ats(projects))
        html = html.replace("{{SKILLS_SECTION}}", _render_skills_ats(skills))
        html = html.replace("{{CERTIFICATIONS_SECTION}}", _section_wrap_ats("Certifications", _render_certs(certs)))
        html = html.replace("{{ACHIEVEMENTS_SECTION}}", _section_wrap_ats("Achievements", _render_achievements(achievements)))
        return html

    # ── EXECUTIVE TEMPLATE (sidebar labels + content) ──
    elif template_name == "executive":
        html = template
        html = html.replace("{{NAME}}", name)
        html = html.replace("{{CONTACT_BLOCK}}", _render_contact_block(r))
        summary_section = _section_wrap_executive("Summary", f"<div>{r.get('summary', '')}</div>") if r.get("summary") else ""
        html = html.replace("{{SUMMARY_SECTION}}", summary_section)
        html = html.replace("{{SKILLS_SECTION}}", _render_skills_executive(skills))
        html = html.replace("{{EXPERIENCE_SECTION}}", _render_experience_executive(experience))
        html = html.replace("{{EDUCATION_SECTION}}", _render_education_executive(education))
        html = html.replace("{{PROJECTS_SECTION}}", _render_projects_executive(projects))
        html = html.replace("{{CERTIFICATIONS_SECTION}}", _section_wrap_executive("Certifications", _render_certs(certs)))
        html = html.replace("{{ACHIEVEMENTS_SECTION}}", _section_wrap_executive("Honors", _render_achievements(achievements)))
        return html

    # ── MODERN TEMPLATE (two-column with teal sidebar) ──
    elif template_name == "modern":
        html = template
        html = html.replace("{{NAME}}", name)
        html = html.replace("{{HEADLINE}}", r.get("headline", ""))
        html = html.replace("{{EMAIL}}", r.get("email", ""))
        html = html.replace("{{PHONE}}", r.get("phone", ""))
        html = html.replace("{{LOCATION}}", r.get("location", ""))
        linkedin = r.get("linkedin", "")
        github = r.get("github", "")
        html = html.replace("{{LINKEDIN_DISPLAY}}", linkedin.replace("https://", "") if linkedin else "")
        html = html.replace("{{GITHUB_DISPLAY}}", github.replace("https://", "") if github else "")
        html = html.replace("{{SIDEBAR_SKILLS}}", _render_modern_sidebar_skill(skills))
        html = html.replace("{{SIDEBAR_CERTS}}", _render_modern_sidebar_certs(certs))
        html = html.replace("{{SIDEBAR_ACHIEVEMENTS}}", _render_modern_sidebar_ach(achievements))
        html = html.replace("{{MAIN_CONTENT}}", _render_modern_main(experience, education, projects))
        return html

    # ── TECH TEMPLATE (dark sidebar with monospace accents) ──
    elif template_name == "tech":
        html = template
        html = html.replace("{{NAME}}", name)
        html = html.replace("{{HEADLINE}}", r.get("headline", ""))
        html = html.replace("{{EMAIL}}", r.get("email", ""))
        html = html.replace("{{PHONE}}", r.get("phone", ""))
        html = html.replace("{{LOCATION}}", r.get("location", ""))
        linkedin = r.get("linkedin", "")
        github = r.get("github", "")
        html = html.replace("{{LINKEDIN_DISPLAY}}", linkedin.replace("https://linkedin.com/in/", "in/") if linkedin else "")
        html = html.replace("{{GITHUB_DISPLAY}}", github.replace("https://github.com/", "gh/") if github else "")
        html = html.replace("{{SIDEBAR_SKILLS}}", _render_tech_sidebar_skill(skills))
        html = html.replace("{{SIDEBAR_CERTS}}", _render_tech_sidebar_certs(certs))
        html = html.replace("{{SIDEBAR_ACHIEVEMENTS}}", _render_tech_sidebar_ach(achievements))
        html = html.replace("{{MAIN_CONTENT}}", _render_tech_main(experience, education, projects))
        return html

    # ── BOLD TEMPLATE (big header with red accent) ──
    elif template_name == "bold":
        html = template
        html = html.replace("{{NAME}}", name)
        html = html.replace("{{HEADLINE}}", r.get("headline", ""))
        html = html.replace("{{CONTACT_BAR_ITEMS}}", _render_bold_contact_bar(r))
        html = html.replace("{{MAIN_CONTENT}}", _render_bold_main(experience, education, projects, skills, certs, achievements))
        return html

    # ── GENERIC TEMPLATES (academic, fresher, minimal) ──
    else:
        html = template
        html = html.replace("{{NAME}}", name)
        html = html.replace("{{HEADLINE}}", r.get("headline", ""))
        html = html.replace("{{CONTACT_LINE}}", _render_contact_line(r))

        use_divider = template_name == "minimal"

        summary_section = _section_wrap_generic("Summary", f'<div class="entry-desc">{r.get("summary", "")}</div>', use_divider) if r.get("summary") else ""
        html = html.replace("{{SUMMARY_SECTION}}", summary_section)
        html = html.replace("{{EXPERIENCE_SECTION}}", _section_wrap_generic("Experience", _render_experience_generic(experience), use_divider))
        html = html.replace("{{EDUCATION_SECTION}}", _section_wrap_generic("Education", _render_education_generic(education), use_divider))
        html = html.replace("{{PROJECTS_SECTION}}", _section_wrap_generic("Projects", _render_projects_generic(projects), use_divider))
        html = html.replace("{{SKILLS_SECTION}}", _section_wrap_generic("Skills", _render_skills_generic(skills), use_divider))
        html = html.replace("{{CERTIFICATIONS_SECTION}}", _section_wrap_generic("Certifications", _render_certs(certs), use_divider))
        html = html.replace("{{ACHIEVEMENTS_SECTION}}", _section_wrap_generic("Achievements", _render_achievements(achievements), use_divider))
        return html


async def generate_pdf(resume_json: dict, template_name: str = "ats_safe") -> bytes:
    """Generate PDF bytes from resume JSON using AI HTML generation."""
    from weasyprint import HTML
    from app.services.resume_ai_service import ai_generate_html

    template_html = _load_template(template_name)
    html_content = await ai_generate_html(resume_json, template_html)
    pdf_bytes = HTML(string=html_content).write_pdf()
    return pdf_bytes
