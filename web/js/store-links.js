/* Generated from web/config/store-links.json — do not edit by hand. */
(function (root, factory) {
  var links = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = links;
  }
  root.HIAIR_STORE_LINKS = links;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  var store = {
  "verifiedAt": "2026-08-29",
  "utm": {
    "utm_source": "hiair_io",
    "utm_medium": "website",
    "utm_campaign": "app_store_cta"
  },
  "ios": {
    "status": "PUBLIC_CONFIRMED",
    "appId": "6773610034",
    "bundleId": "com.hiair.app",
    "name": "HiAir",
    "sellerName": "Aleksandr Potkin",
    "url": "https://apps.apple.com/us/app/hiair/id6773610034",
    "verification": "iTunes Lookup API resultCount=1 plus public storefront apps.apple.com/app/id6773610034 (US/ES) showing HiAir, bundleId com.hiair.app, version 1.1"
  },
  "android": {
    "status": "NOT_PUBLIC",
    "packageId": "com.hiair",
    "name": "HiAir",
    "url": null,
    "verification": "Public Play storefront https://play.google.com/store/apps/details?id=com.hiair returned HTTP 404 / CRAWL_NOT_FOUND on 2026-08-29"
  }
};
  function campaignUrl(baseUrl, placement) {
    if (!baseUrl) {
      return "";
    }
    var utm = store.utm || {};
    var params = new URLSearchParams();
    params.set("utm_source", utm.utm_source || "hiair_io");
    params.set("utm_medium", utm.utm_medium || "website");
    params.set("utm_campaign", utm.utm_campaign || "app_store_cta");
    params.set("utm_content", placement);
    params.set("ct", "app_store_cta_" + placement);
    return baseUrl + "?" + params.toString();
  }
  store.appStoreCampaignUrl = function (placement) {
    if (!store.ios || store.ios.status !== "PUBLIC_CONFIRMED" || !store.ios.url) {
      return "";
    }
    return campaignUrl(store.ios.url, placement || "unknown");
  };
  store.playStoreCampaignUrl = function (placement) {
    if (!store.android || store.android.status !== "PUBLIC_CONFIRMED" || !store.android.url) {
      return "";
    }
    return campaignUrl(store.android.url, placement || "unknown");
  };
  store.isPublic = function (platform) {
    var entry = store[platform];
    return !!(entry && entry.status === "PUBLIC_CONFIRMED" && entry.url);
  };
  return store;
});
