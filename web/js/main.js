(function () {
  "use strict";

  var GROWTH_OS_EVENTS_URL_FROM_BUILD = "__GROWTH_OS_EVENTS_URL__";

  const API_BASE =
    window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1"
      ? "http://127.0.0.1:8000"
      : "https://api.hiair.io";

  /* Liquid Glass — cursor glow on hero mockup */
  function attachGlow(el) {
    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      el.addEventListener("pointermove", function (e) {
        var r = el.getBoundingClientRect();
        el.style.setProperty("--gx", (e.clientX - r.left) + "px");
        el.style.setProperty("--gy", (e.clientY - r.top) + "px");
      });
    }
  }

  document.querySelectorAll(".lg--glow").forEach(attachGlow);

  /* Mobile nav */
  const navToggle = document.querySelector(".nav-toggle");
  const siteNav = document.getElementById("site-nav");

  if (navToggle && siteNav) {
    function setNavOpen(open) {
      siteNav.classList.toggle("is-open", open);
      navToggle.setAttribute("aria-expanded", String(open));
      navToggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    }

    navToggle.addEventListener("click", function () {
      setNavOpen(!siteNav.classList.contains("is-open"));
    });

    siteNav.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        setNavOpen(false);
      });
    });

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && siteNav.classList.contains("is-open")) {
        setNavOpen(false);
        navToggle.focus();
      }
    });
  }

  /* FAQ accordion */
  document.querySelectorAll(".faq-item").forEach(function (item) {
    const btn = item.querySelector(".faq-question");
    if (!btn) return;

    btn.addEventListener("click", function () {
      const isOpen = item.classList.toggle("is-open");
      btn.setAttribute("aria-expanded", String(isOpen));

      if (isOpen) {
        trackGrowth("faq_opened", { placement: btn.getAttribute("aria-controls") || "faq" });
      }

      document.querySelectorAll(".faq-item").forEach(function (other) {
        if (other !== item && other.classList.contains("is-open")) {
          other.classList.remove("is-open");
          const otherBtn = other.querySelector(".faq-question");
          if (otherBtn) otherBtn.setAttribute("aria-expanded", "false");
        }
      });
    });
  });

  function storeLinks() {
    return window.HIAIR_STORE_LINKS || null;
  }

  function applyVerifiedStoreCtas() {
    var links = storeLinks();
    if (!links) {
      return;
    }

    document.querySelectorAll(".js-app-store-cta").forEach(function (el) {
      if (!links.isPublic || !links.isPublic("ios")) {
        el.remove();
        return;
      }
      var placement = el.getAttribute("data-placement") || "unknown";
      var href = links.appStoreCampaignUrl(placement);
      if (href) {
        el.setAttribute("href", href);
        el.setAttribute("target", "_blank");
        el.setAttribute("rel", "noopener noreferrer");
      }
    });

    document.querySelectorAll(".js-play-store-cta").forEach(function (el) {
      if (!links.isPublic || !links.isPublic("android")) {
        el.remove();
        return;
      }
      var placement = el.getAttribute("data-placement") || "unknown";
      var href = links.playStoreCampaignUrl(placement);
      if (href) {
        el.setAttribute("href", href);
        el.setAttribute("target", "_blank");
        el.setAttribute("rel", "noopener noreferrer");
      }
    });
  }

  applyVerifiedStoreCtas();

  /* Android notify form */
  const form = document.getElementById("waitlist-form");
  const messageEl = document.getElementById("waitlist-message");
  const submitBtn = document.getElementById("waitlist-submit");

  function showMessage(text, type) {
    if (!messageEl) return;
    messageEl.textContent = text;
    messageEl.className = "form-message is-visible " + type;
  }

  if (form) {
    let waitlistInFlight = false;

    form.addEventListener("submit", async function (event) {
      event.preventDefault();
      if (waitlistInFlight) {
        return;
      }

      const emailInput = document.getElementById("waitlist-email");
      const personaSelect = document.getElementById("waitlist-persona");
      const email = emailInput ? emailInput.value.trim() : "";
      const persona = personaSelect && personaSelect.value ? personaSelect.value : null;

      if (!email || !email.includes("@")) {
        showMessage("Please enter a valid email address.", "error");
        emailInput && emailInput.focus();
        return;
      }

      waitlistInFlight = true;
      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.setAttribute("aria-busy", "true");
        submitBtn.textContent = "Sending…";
      }
      showMessage("", "");

      const payload = { email: email };
      if (persona) payload.persona = persona;

      try {
        const response = await fetch(API_BASE + "/api/waitlist", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });

        const data = await response.json().catch(function () {
          return {};
        });

        if (response.ok) {
          showMessage(
            "You're on the list. We'll email you when Android is publicly available.",
            "success"
          );
          form.reset();
        } else {
          const detail = data.detail;
          const errText =
            typeof detail === "string"
              ? detail
              : Array.isArray(detail)
                ? detail.map(function (d) { return d.msg || d; }).join(" ")
                : "Something went wrong. Please try again.";
          showMessage(errText, "error");
        }
      } catch (_err) {
        showMessage(
          "Could not reach our servers. Please try again in a moment or email hello@hiair.io.",
          "error"
        );
      } finally {
        waitlistInFlight = false;
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.removeAttribute("aria-busy");
          submitBtn.textContent = "Notify me about Android";
        }
      }
    });
  }

  function growthOsEventsUrl() {
    if (window.GROWTH_OS_EVENTS_URL) {
      return window.GROWTH_OS_EVENTS_URL;
    }
    if (typeof GROWTH_OS_EVENTS_URL_FROM_BUILD === "string" && GROWTH_OS_EVENTS_URL_FROM_BUILD.indexOf("__GROWTH_OS") !== 0) {
      return GROWTH_OS_EVENTS_URL_FROM_BUILD;
    }
    if (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1") {
      return "http://localhost:3001/api/v1/events";
    }
    return "";
  }

  function growthAnonymousId() {
    var key = "hiair_growth_anon";
    try {
      var existing = window.localStorage.getItem(key);
      if (existing) {
        return existing;
      }
      var created = (window.crypto && window.crypto.randomUUID && window.crypto.randomUUID()) || String(Date.now());
      window.localStorage.setItem(key, created);
      return created;
    } catch (error) {
      return "anon";
    }
  }

  function growthSessionId() {
    var key = "hiair_growth_session";
    try {
      var existing = window.sessionStorage.getItem(key);
      if (existing) {
        return existing;
      }
      var created = (window.crypto && window.crypto.randomUUID && window.crypto.randomUUID()) || String(Date.now());
      window.sessionStorage.setItem(key, created);
      return created;
    } catch (error) {
      return "session";
    }
  }

  function growthEventId(name, placement) {
    var key = "hiair_growth_evt:" + name + ":" + placement;
    try {
      var existing = window.sessionStorage.getItem(key);
      if (existing) {
        return existing;
      }
      var created = (window.crypto && window.crypto.randomUUID && window.crypto.randomUUID()) || String(Date.now()) + placement;
      window.sessionStorage.setItem(key, created);
      return created;
    } catch (error) {
      return name + "-" + placement;
    }
  }

  function utmFromLocation() {
    var params = new URLSearchParams(window.location.search);
    var properties = {};
    ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term"].forEach(function (key) {
      var value = params.get(key);
      if (value) {
        properties[key] = value.slice(0, 200);
      }
    });
    return properties;
  }

  function trackGrowth(name, properties) {
    var url = growthOsEventsUrl();
    if (!url) {
      return;
    }
    properties = properties || {};
    var body = {
      productSlug: "hiair",
      surface: "website",
      environment: "production",
      anonymousId: growthAnonymousId(),
      session_id: growthSessionId(),
      event_id: growthEventId(name, properties.placement || "unknown"),
      event_version: 1,
      name: name,
      occurredAt: new Date().toISOString(),
      properties: Object.assign(
        {
          page: window.location.pathname,
          locale: document.documentElement.lang || "en",
          campaign: "app_store_cta",
        },
        utmFromLocation(),
        properties
      ),
    };
    try {
      fetch(url, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
        keepalive: true,
      }).catch(function () {});
    } catch (error) {
      return;
    }
  }

  var runtimeStoreLinks = window.HIAIR_STORE_LINKS;
  if (runtimeStoreLinks && runtimeStoreLinks.isPublic && runtimeStoreLinks.isPublic("ios") && typeof runtimeStoreLinks.appStoreCampaignUrl === "function") {
    document.querySelectorAll(".js-app-store-cta").forEach(function (el) {
      var href = runtimeStoreLinks.appStoreCampaignUrl(el.getAttribute("data-placement") || "unknown");
      if (href) {
        el.setAttribute("href", href);
        el.setAttribute("target", "_blank");
        el.setAttribute("rel", "noopener noreferrer");
      }
    });
  }

  var HIAIR_EXPERIMENTS_ENABLED = false;

  var storeCtas = document.querySelectorAll(".js-app-store-cta");
  if (storeCtas.length) {
    var viewed = {};
    storeCtas.forEach(function (el) {
      var placement = el.getAttribute("data-placement") || "unknown";
      if (!viewed[placement]) {
        viewed[placement] = true;
        trackGrowth("app_store_cta.viewed", {
          page: window.location.pathname,
          placement: placement,
          locale: document.documentElement.lang || "en",
          campaign: "app_store_cta",
        });
      }
      el.addEventListener("click", function () {
        trackGrowth("app_store_cta.clicked", {
          page: window.location.pathname,
          placement: placement,
          locale: document.documentElement.lang || "en",
          campaign: "app_store_cta",
        });
        trackGrowth("ios_download_click", { placement: placement });
        var explicitEvent = el.getAttribute("data-event");
        if (explicitEvent && explicitEvent !== "ios_download_click") {
          trackGrowth(explicitEvent, { placement: placement });
        }
      });
    });
  }

  document.querySelectorAll(".js-play-store-cta").forEach(function (el) {
    el.addEventListener("click", function () {
      trackGrowth("android_download_click", {
        placement: el.getAttribute("data-placement") || "unknown",
      });
    });
  });

  /* Deterministic product demo — no location or health data leaves the page. */
  var demoForm = document.getElementById("product-demo");
  if (demoForm) {
    var demoStarted = false;
    var demoExamples = {
      barcelona: {
        walk: ["43", "Moderate", "19:00–21:00", "Lower heat and improving air conditions make the evening a better fit for a walk."],
        run: ["58", "Moderate", "20:00–21:00", "A later, shorter run avoids the warmest part of this example day."],
        outdoor: ["47", "Moderate", "18:30–21:00", "The evening is the more suitable outdoor window in this example."],
      },
      madrid: {
        walk: ["55", "Moderate", "20:00–22:00", "Heat eases later, making the evening a better fit for a walk."],
        run: ["68", "High", "21:00–22:00", "This example favors a later, lower-intensity run after peak heat."],
        outdoor: ["61", "Moderate", "20:30–22:00", "Waiting until later reduces the main heat concern in this example."],
      },
      london: {
        walk: ["28", "Low", "10:00–12:00", "Milder heat and lower example pollution make late morning more suitable."],
        run: ["36", "Low", "09:00–11:00", "The late-morning window has the best balance for this sample run."],
        outdoor: ["31", "Low", "10:00–14:00", "A broad midday window is suitable in this deterministic example."],
      },
    };

    function markDemoStarted() {
      if (demoStarted) return;
      demoStarted = true;
      trackGrowth("demo_started", { placement: "homepage_demo" });
    }

    demoForm.addEventListener("change", markDemoStarted);
    demoForm.addEventListener("focusin", markDemoStarted);
    demoForm.addEventListener("submit", function (event) {
      event.preventDefault();
      markDemoStarted();

      var locationSelect = document.getElementById("demo-location");
      var activitySelect = document.getElementById("demo-activity");
      var locationKey = locationSelect ? locationSelect.value : "barcelona";
      var activityKey = activitySelect ? activitySelect.value : "walk";
      var city = locationSelect && locationSelect.options[locationSelect.selectedIndex]
        ? locationSelect.options[locationSelect.selectedIndex].text
        : "Barcelona";
      var activity = activitySelect && activitySelect.options[activitySelect.selectedIndex]
        ? activitySelect.options[activitySelect.selectedIndex].text
        : "Walk";
      var example = (demoExamples[locationKey] && demoExamples[locationKey][activityKey]) || demoExamples.barcelona.walk;

      var locationOutput = document.getElementById("demo-result-location");
      var scoreOutput = document.getElementById("demo-risk-score");
      var labelOutput = document.getElementById("demo-risk-label");
      var windowOutput = document.getElementById("demo-window");
      var reasonOutput = document.getElementById("demo-reason");
      if (locationOutput) locationOutput.textContent = city + " · " + activity;
      if (scoreOutput) scoreOutput.textContent = example[0];
      if (labelOutput) labelOutput.textContent = example[1];
      if (windowOutput) windowOutput.textContent = example[2];
      if (reasonOutput) reasonOutput.textContent = example[3];

      trackGrowth("demo_completed", { placement: "homepage_demo" });
    });
  }

  var trackedViews = document.querySelectorAll("[data-track-view]");
  if (trackedViews.length && "IntersectionObserver" in window) {
    var viewObserver = new window.IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        var name = entry.target.getAttribute("data-track-view");
        if (name) {
          trackGrowth(name, { placement: entry.target.id || "section" });
        }
        viewObserver.unobserve(entry.target);
      });
    }, { threshold: 0.35 });
    trackedViews.forEach(function (el) { viewObserver.observe(el); });
  }

  if (HIAIR_EXPERIMENTS_ENABLED && window.HIAIR_GROWTH_EXPERIMENT && typeof window.HIAIR_GROWTH_EXPERIMENT.start === "function") {
    window.HIAIR_GROWTH_EXPERIMENT.start({ enabled: true });
  }
})();
