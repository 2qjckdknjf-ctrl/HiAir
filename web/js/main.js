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

  var storeLinks = window.HIAIR_STORE_LINKS;
  if (storeLinks && storeLinks.isPublic && storeLinks.isPublic("ios") && typeof storeLinks.appStoreCampaignUrl === "function") {
    document.querySelectorAll(".js-app-store-cta").forEach(function (el) {
      var href = storeLinks.appStoreCampaignUrl(el.getAttribute("data-placement") || "unknown");
      if (href) {
        el.setAttribute("href", href);
        el.setAttribute("target", "_blank");
        el.setAttribute("rel", "noopener noreferrer");
      }
    });
  }

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
      });
    });
  }
})();
