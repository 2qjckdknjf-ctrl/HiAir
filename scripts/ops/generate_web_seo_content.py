#!/usr/bin/env python3
"""Generate the static, indexable HiAir content hub.

The marketing site is deployed as a directory by Cloudflare Pages. Keeping the
repeated navigation, metadata and structured data in one generator makes the
static HTML deterministic without adding a runtime framework.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "web"
TODAY = "2026-08-25"


PAGES = [
    {
        "path": "guides",
        "title": "Heat and Air Quality Guides | HiAir",
        "description": "Practical, source-backed guides for understanding AQI, exercising in heat, planning family outdoor time, and deciding when to ventilate.",
        "eyebrow": "HiAir guides",
        "heading": "Make clearer decisions about heat and air quality",
        "intro": "Short, practical explanations for the moments when a weather number is not enough. HiAir provides wellness guidance, not diagnosis or emergency advice.",
        "kind": "CollectionPage",
        "body": """
          <div class="content-grid content-grid--3">
            <a class="resource-card" href="/guides/aqi-explained/">
              <span class="resource-card__label">Air quality</span>
              <h2>AQI explained in plain language</h2>
              <p>Understand the index, sensitive-group warnings, and why the pollutant behind the number matters.</p>
              <span class="text-link">Read the guide →</span>
            </a>
            <a class="resource-card" href="/guides/exercise-in-heat/">
              <span class="resource-card__label">Outdoor activity</span>
              <h2>How to plan exercise in hot weather</h2>
              <p>Use timing, intensity, heat and air quality together before choosing an outdoor workout window.</p>
              <span class="text-link">Read the guide →</span>
            </a>
            <a class="resource-card" href="/guides/when-to-open-windows/">
              <span class="resource-card__label">Home</span>
              <h2>When should you open the windows?</h2>
              <p>Compare outdoor pollution and temperature with indoor comfort instead of following one fixed rule.</p>
              <span class="text-link">Read the guide →</span>
            </a>
          </div>
          <section class="content-section">
            <p class="section-eyebrow">Choose your situation</p>
            <h2>Guidance built around real plans</h2>
            <div class="content-grid content-grid--3">
              <a class="topic-card" href="/for-families/"><strong>Families</strong><span>Plan playground time and outdoor routines.</span></a>
              <a class="topic-card" href="/for-runners/"><strong>Runners & cyclists</strong><span>Find a more comfortable training window.</span></a>
              <a class="topic-card" href="/air-quality-sensitive/"><strong>Air-quality sensitive</strong><span>Understand combined environmental signals.</span></a>
            </div>
          </section>
        """,
    },
    {
        "path": "guides/aqi-explained",
        "title": "What Is AQI? Air Quality Index Explained | HiAir",
        "description": "Learn what AQI means, how common AQI categories work, and why heat, ozone, particles and personal sensitivity should be considered together.",
        "eyebrow": "Air quality guide",
        "heading": "AQI explained: what the number can—and cannot—tell you",
        "intro": "AQI turns measured air pollutants into a simpler public-health scale. It is useful, but it is not a personal diagnosis and scales can differ between countries.",
        "kind": "Article",
        "body": """
          <section class="content-section prose-content">
            <h2>The short answer</h2>
            <p>A higher Air Quality Index generally means greater potential concern from outdoor air pollution. In the United States, AirNow groups daily AQI values from Good through Hazardous and explains that sensitive people may face concern before the general population.</p>
            <div class="callout"><strong>Important:</strong> always check which country or provider produced the AQI. A value from one national scale is not automatically equivalent to the same number on another scale.</div>
            <h2>What is behind the AQI?</h2>
            <p>The displayed number may be driven by particles such as PM2.5 or by ozone and other regulated pollutants. That matters because the pattern through the day can differ. HiAir therefore keeps the environmental signals explainable instead of treating the headline number as the whole story.</p>
            <h2>Why a personal view is useful</h2>
            <p>Two people can make different plans under the same conditions. Intended activity, heat, humidity and personal sensitivity can change whether the practical next step is to shorten a workout, choose a later hour, or follow an official local advisory.</p>
            <h2>What to do next</h2>
            <ul>
              <li>Check the current AQI and the pollutant responsible.</li>
              <li>Look at the hourly trend, not only the daily maximum.</li>
              <li>Consider heat and the intensity of your planned activity.</li>
              <li>Follow local authority guidance during smoke or pollution events.</li>
            </ul>
            <p class="source-note">Primary reference: <a href="https://www.airnow.gov/aqi/aqi-basics/" rel="noopener">AirNow — AQI Basics</a>.</p>
          </section>
        """,
    },
    {
        "path": "guides/exercise-in-heat",
        "title": "Exercise in Hot Weather: Plan a Safer Time | HiAir",
        "description": "A practical guide to choosing an outdoor workout window using heat, humidity, air quality, timing and your own response.",
        "eyebrow": "Outdoor activity guide",
        "heading": "Plan outdoor exercise around more than temperature",
        "intro": "A clear sky does not guarantee a comfortable workout. Heat, humidity, ozone, particles, activity intensity and personal response all belong in the decision.",
        "kind": "Article",
        "body": """
          <section class="content-section prose-content">
            <h2>Start with the hour, not only the day</h2>
            <p>Conditions can change substantially between morning, midday and evening. Check an hourly view and look for a cooler, cleaner window that fits the intended intensity of your workout.</p>
            <h2>A simple pre-workout check</h2>
            <ol>
              <li>Review heat, humidity and the local heat alert.</li>
              <li>Review AQI and the pollutant driving it.</li>
              <li>Reduce duration or intensity when conditions are less favorable.</li>
              <li>Choose an earlier or later hour when possible.</li>
              <li>Stop activity and move to a cool place if you feel faint or weak.</li>
            </ol>
            <div class="callout"><strong>Emergency warning:</strong> HiAir is not an emergency service. Symptoms of heat illness require appropriate professional or emergency help.</div>
            <h2>How HiAir approaches the decision</h2>
            <p>HiAir combines available environmental signals with your activity context and sensitivity settings, then explains why a time window looks better or worse. Missing forecast data stays missing; it is not silently invented.</p>
            <p class="source-note">Primary references: <a href="https://www.cdc.gov/heat-health/risk-factors/heat-and-athletes.html" rel="noopener">CDC — Heat and Athletes</a> and <a href="https://www.who.int/news-room/fact-sheets/detail/climate-change-heat-and-health" rel="noopener">WHO — Heat and health</a>.</p>
          </section>
        """,
    },
    {
        "path": "guides/when-to-open-windows",
        "title": "When Should You Open Windows? Heat and AQI Guide | HiAir",
        "description": "Learn how outdoor temperature, air quality, smoke and indoor comfort affect the best time to ventilate your home.",
        "eyebrow": "Ventilation guide",
        "heading": "When should you open the windows?",
        "intro": "There is no single hour that works every day. The better decision compares outdoor air quality and temperature with conditions inside your home.",
        "kind": "Article",
        "body": """
          <section class="content-section prose-content">
            <h2>Two questions to check first</h2>
            <ol>
              <li>Is outdoor air quality currently suitable for ventilation?</li>
              <li>Is outdoor air cooler or more comfortable than indoor air?</li>
            </ol>
            <p>During heat, nighttime or early morning may be cooler. During smoke, dust or pollution episodes, local authorities may advise keeping outdoor air out even if the temperature feels better.</p>
            <h2>A practical decision pattern</h2>
            <ul>
              <li><strong>Cleaner and cooler outside:</strong> ventilation may be useful if it is otherwise safe.</li>
              <li><strong>Polluted or smoky outside:</strong> follow local advisories and consider filtration or mechanical ventilation guidance.</li>
              <li><strong>Hotter outside than inside:</strong> windows and shading may be more useful closed during the hottest hours.</li>
              <li><strong>Uncertain data:</strong> avoid presenting a precise “best hour” as fact.</li>
            </ul>
            <div class="callout"><strong>Safety comes first:</strong> window security, children, local fire guidance and building-specific ventilation requirements can override general suggestions.</div>
            <p class="source-note">Primary references: <a href="https://www.epa.gov/indoor-air-quality-iaq/biological-contaminants-and-indoor-air-quality" rel="noopener">US EPA — Indoor air and ventilation</a> and <a href="https://www.who.int/news-room/fact-sheets/detail/climate-change-heat-and-health" rel="noopener">WHO — Heat and health</a>.</p>
          </section>
        """,
    },
    {
        "path": "for-families",
        "title": "Heat and Air Quality Guidance for Families | HiAir",
        "description": "Plan outdoor time for your family with clearer hourly context for heat, humidity and air quality. Wellness guidance, not medical advice.",
        "eyebrow": "HiAir for families",
        "heading": "Choose a better time for family outdoor plans",
        "intro": "HiAir helps an adult account holder compare heat, humidity and air quality before playground time, school walks and other outdoor routines.",
        "kind": "WebPage",
        "body": """
          <div class="content-grid content-grid--3">
            <div class="feature-card"><span>01</span><h2>See the day hour by hour</h2><p>Compare morning, midday and evening instead of relying on one daily number.</p></div>
            <div class="feature-card"><span>02</span><h2>Understand the reason</h2><p>See whether heat, humidity, particles or ozone contributes to the current guidance.</p></div>
            <div class="feature-card"><span>03</span><h2>Plan a practical action</h2><p>Consider a different time, shorter activity, shade or an indoor alternative.</p></div>
          </div>
          <section class="content-section prose-content">
            <h2>Designed for adult decision-making</h2>
            <p>HiAir accounts are for people aged 13 and older. A family or children-outdoor profile is guidance for the adult account holder; it is not a child account and does not diagnose a child’s condition.</p>
            <h2>Useful before</h2>
            <ul><li>Playground visits and family walks</li><li>School travel and outdoor events</li><li>Sports practice and summer activities</li><li>Ventilating bedrooms and shared spaces</li></ul>
          </section>
        """,
    },
    {
        "path": "for-runners",
        "title": "Heat and Air Quality Planner for Runners | HiAir",
        "description": "Find a more suitable running or cycling window by comparing hourly heat, humidity and air quality with your activity.",
        "eyebrow": "HiAir for runners",
        "heading": "Find the better outdoor training window",
        "intro": "Use hourly environmental context to decide whether to train now, go later, reduce intensity or choose an indoor session.",
        "kind": "WebPage",
        "body": """
          <div class="content-grid content-grid--3">
            <div class="feature-card"><span>01</span><h2>Hourly windows</h2><p>Compare likely conditions across the hours available for your training.</p></div>
            <div class="feature-card"><span>02</span><h2>Combined context</h2><p>Review heat, humidity and air-quality signals in the same decision.</p></div>
            <div class="feature-card"><span>03</span><h2>Explainable guidance</h2><p>Understand why a window is preferred and where forecast data is unavailable.</p></div>
          </div>
          <section class="content-section prose-content">
            <h2>Before you head out</h2>
            <p>Check the current local alert, the hourly trend and how you feel. Hot-weather exercise increases the risk of dehydration and heat-related illness. If you feel faint or weak, stop activity and move to a cool place.</p>
            <p class="source-note">Reference: <a href="https://www.cdc.gov/heat-health/risk-factors/heat-and-athletes.html" rel="noopener">CDC — Heat and Athletes</a>.</p>
          </section>
        """,
    },
    {
        "path": "air-quality-sensitive",
        "title": "Personal Air Quality and Heat Guidance | HiAir",
        "description": "Understand combined heat and air-quality signals with sensitivity settings and clear, non-medical daily guidance.",
        "eyebrow": "Personal environmental context",
        "heading": "Go beyond a generic air-quality number",
        "intro": "HiAir combines available environmental data with the sensitivity settings you choose, while keeping guidance explainable and firmly within wellness use.",
        "kind": "WebPage",
        "body": """
          <div class="content-grid content-grid--3">
            <div class="feature-card"><span>01</span><h2>Multiple signals</h2><p>See heat, humidity, AQI, particles, ozone and smoke when those inputs are available.</p></div>
            <div class="feature-card"><span>02</span><h2>Your settings</h2><p>Use an optional sensitivity profile to shape how the app presents environmental caution.</p></div>
            <div class="feature-card"><span>03</span><h2>Honest uncertainty</h2><p>Unavailable data remains clearly unavailable instead of appearing as a safe zero.</p></div>
          </div>
          <section class="content-section prose-content">
            <h2>What HiAir does not do</h2>
            <p>HiAir does not diagnose asthma, allergies or any other condition. It does not replace local public-health alerts, a clinician or emergency services. It helps you organize environmental information for everyday planning.</p>
            <p><a class="text-link" href="/methodology/">Read how HiAir produces guidance →</a></p>
          </section>
        """,
    },
    {
        "path": "methodology",
        "title": "How HiAir Guidance Works | Methodology",
        "description": "Learn how HiAir combines weather, air quality, activity context and optional sensitivity settings while handling missing data honestly.",
        "eyebrow": "Methodology",
        "heading": "From environmental signals to explainable guidance",
        "intro": "HiAir is designed to make everyday environmental decisions easier without pretending that a model can diagnose health or guarantee safety.",
        "kind": "WebPage",
        "body": """
          <section class="method-steps" aria-label="HiAir methodology">
            <div><span>1</span><h2>Collect</h2><p>Use available time-stamped weather and air-quality inputs for the selected location.</p></div>
            <div><span>2</span><h2>Interpret</h2><p>Consider the planned activity and optional sensitivity settings alongside the environment.</p></div>
            <div><span>3</span><h2>Explain</h2><p>Show a clear level, reason codes and practical wellness actions for the relevant time window.</p></div>
            <div><span>4</span><h2>Stay honest</h2><p>Label missing, stale or unavailable information instead of silently manufacturing certainty.</p></div>
          </section>
          <section class="content-section prose-content">
            <h2>Safety boundaries</h2>
            <ul><li>Wellness guidance only; no diagnosis or treatment.</li><li>Official local warnings take priority.</li><li>No emergency prediction or emergency response.</li><li>Environmental data and forecasts can be incomplete or delayed.</li><li>Optional wearable summaries add context, not medical conclusions.</li></ul>
            <h2>Privacy principles</h2>
            <p>Location, notifications and health-platform access are optional. HiAir uses aggregated wearable summaries only after explicit system permission and does not sell personal data.</p>
            <p><a class="text-link" href="/privacy/">Read the Privacy Policy →</a></p>
          </section>
        """,
    },
    {
        "path": "about",
        "title": "About HiAir | Breathe Better. Live Better.",
        "description": "HiAir turns complex heat and air-quality signals into calm, explainable guidance for everyday outdoor decisions.",
        "eyebrow": "About HiAir",
        "heading": "Weather data is abundant. Clear decisions are not.",
        "intro": "HiAir was created to answer the practical question behind the forecast: what does this combination of heat and air quality mean for the plan I am making today?",
        "kind": "AboutPage",
        "body": """
          <section class="content-section prose-content">
            <h2>Our product principles</h2>
            <ul><li><strong>Calm:</strong> communicate risk without alarmist noise.</li><li><strong>Personal:</strong> use only the context a person chooses to provide.</li><li><strong>Explainable:</strong> show the reasons behind guidance.</li><li><strong>Honest:</strong> never disguise missing data as certainty.</li><li><strong>Private:</strong> minimize collection and keep control with the user.</li></ul>
            <h2>Where HiAir is going</h2>
            <p>HiAir is preparing wider availability for iOS and Android, with an initial focus on regions where heat and air-quality conditions frequently affect outdoor life.</p>
          </section>
        """,
    },
    {
        "path": "contact",
        "title": "Contact HiAir",
        "description": "Contact HiAir for product support, privacy questions, partnerships, media requests or early-access information.",
        "eyebrow": "Contact",
        "heading": "Talk with the HiAir team",
        "intro": "Choose the closest topic and include enough context for us to route your message. Do not send emergency or highly sensitive medical information.",
        "kind": "ContactPage",
        "body": """
          <div class="content-grid content-grid--3">
            <a class="resource-card" href="mailto:hello@hiair.io?subject=HiAir%20product%20support"><span class="resource-card__label">Support</span><h2>Product help</h2><p>Account, access, app behavior or general questions.</p><span class="text-link">hello@hiair.io →</span></a>
            <a class="resource-card" href="mailto:hello@hiair.io?subject=HiAir%20partnership"><span class="resource-card__label">Growth</span><h2>Partnerships</h2><p>Running clubs, community organizations, publishers and workplace programs.</p><span class="text-link">Start a conversation →</span></a>
            <a class="resource-card" href="mailto:hello@hiair.io?subject=HiAir%20privacy"><span class="resource-card__label">Privacy</span><h2>Data request</h2><p>Privacy, access, correction, export or deletion questions.</p><span class="text-link">Contact the controller →</span></a>
          </div>
        """,
    },
]


def structured_data(page: dict[str, str]) -> str:
    url = f"https://hiair.io/{page['path']}/"
    data: dict[str, object] = {
        "@context": "https://schema.org",
        "@type": page["kind"],
        "name": page["heading"],
        "headline": page["heading"],
        "description": page["description"],
        "url": url,
        "inLanguage": "en",
        "isPartOf": {"@type": "WebSite", "name": "HiAir", "url": "https://hiair.io/"},
        "publisher": {"@type": "Organization", "name": "HiAir", "url": "https://hiair.io/"},
    }
    if page["kind"] == "Article":
        data["datePublished"] = TODAY
        data["dateModified"] = TODAY
    return json.dumps(data, ensure_ascii=False, separators=(",", ":"))


def render(page: dict[str, str]) -> str:
    canonical = f"https://hiair.io/{page['path']}/"
    return f"""<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{page['title']}</title>
    <meta name="description" content="{page['description']}" />
    <meta name="robots" content="index, follow, max-image-preview:large" />
    <link rel="canonical" href="{canonical}" />
    <meta property="og:type" content="{'article' if page['kind'] == 'Article' else 'website'}" />
    <meta property="og:url" content="{canonical}" />
    <meta property="og:site_name" content="HiAir" />
    <meta property="og:title" content="{page['title']}" />
    <meta property="og:description" content="{page['description']}" />
    <meta property="og:image" content="https://hiair.io/icon-1024.png" />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="{page['title']}" />
    <meta name="twitter:description" content="{page['description']}" />
    <meta name="twitter:image" content="https://hiair.io/icon-1024.png" />
    <meta name="theme-color" content="#0b1730" />
    <link rel="icon" type="image/png" sizes="40x40" href="/favicon-40.png" />
    <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />
    <link rel="manifest" href="/site.webmanifest" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
    <link rel="stylesheet" href="/styles.css" />
    <link rel="stylesheet" href="/glass.css" />
    <link rel="stylesheet" href="/content.css" />
    <script type="application/ld+json">{structured_data(page)}</script>
  </head>
  <body class="content-page">
    <a class="skip-link" href="#main">Skip to content</a>
    <header class="site-header">
      <div class="container">
        <div class="content-nav">
          <a class="brand" href="/" aria-label="HiAir home">
            <img class="brand__mark" src="/assets/brand/logo-mark.png" alt="" aria-hidden="true" />
            <img class="brand__wordmark" src="/assets/brand/wordmark-light.png" alt="HiAir" />
          </a>
          <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="site-nav" aria-label="Open menu">
            <span class="nav-toggle__tint" aria-hidden="true"></span>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" /></svg>
          </button>
          <nav id="site-nav" class="site-nav" aria-label="Primary">
            <a href="/guides/">Guides</a><a href="/for-families/">Families</a><a href="/for-runners/">Runners</a><a href="/methodology/">Methodology</a><a class="btn btn-primary" href="/#waitlist">Join early access</a>
          </nav>
        </div>
      </div>
    </header>
    <main id="main">
      <section class="content-hero">
        <div class="container content-hero__grid">
          <div>
            <p class="section-eyebrow">{page['eyebrow']}</p>
            <h1>{page['heading']}</h1>
            <p class="content-hero__lead">{page['intro']}</p>
          </div>
          <img class="content-hero__orb" src="/assets/brand/orb.png" alt="" aria-hidden="true" />
        </div>
      </section>
      <div class="container content-main">
        {page['body']}
        <section class="content-cta" aria-labelledby="content-cta-title">
          <p class="section-eyebrow">Personalize the next step</p>
          <h2 id="content-cta-title">Turn environmental data into a plan for your day</h2>
          <p>Join the HiAir early-access list for iOS and Android availability in your region.</p>
          <a class="btn btn-primary" href="/#waitlist">Join early access</a>
        </section>
        <p class="review-date">Last reviewed {TODAY}. Wellness guidance only — not medical advice.</p>
      </div>
    </main>
    <footer class="site-footer">
      <div class="container">
        <div class="footer-grid">
          <div class="footer-brand"><a class="footer-brand-lockup" href="/"><img src="/assets/brand/mono-light.png" alt="HiAir" /></a><p>Breathe better. Live better. Personalized heat and air wellness for everyday life.</p></div>
          <div class="footer-links"><h2>Explore</h2><ul><li><a href="/guides/">Guides</a></li><li><a href="/methodology/">Methodology</a></li><li><a href="/about/">About</a></li><li><a href="/contact/">Contact</a></li></ul></div>
          <div class="footer-links"><h2>Legal</h2><ul><li><a href="/privacy/">Privacy Policy</a></li><li><a href="/terms/">Terms of Service</a></li><li><a href="mailto:hello@hiair.io">hello@hiair.io</a></li></ul></div>
        </div>
        <div class="footer-bottom"><p>&copy; HiAir. All rights reserved.</p><p class="footer-disclaimer">HiAir provides wellness guidance and is not a substitute for professional medical advice. In emergencies, contact local emergency services.</p></div>
      </div>
    </footer>
    <script src="/js/main.js" defer></script>
  </body>
</html>
"""


def main() -> None:
    for page in PAGES:
        destination = WEB / page["path"] / "index.html"
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(render(page), encoding="utf-8")

    urls = ["https://hiair.io/", *(f"https://hiair.io/{page['path']}/" for page in PAGES), "https://hiair.io/privacy/", "https://hiair.io/terms/"]
    sitemap = ['<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    for url in urls:
        sitemap.extend(("  <url>", f"    <loc>{url}</loc>", f"    <lastmod>{TODAY}</lastmod>", "  </url>"))
    sitemap.append("</urlset>")
    (WEB / "sitemap.xml").write_text("\n".join(sitemap) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
