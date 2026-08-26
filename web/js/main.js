(function () {
  "use strict";

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

  /* Waitlist form */
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
        submitBtn.textContent = "Joining…";
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
            data.message || "You're on the list. We'll email you when early access opens.",
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
          submitBtn.textContent = "Join early access";
        }
      }
    });
  }
})();
