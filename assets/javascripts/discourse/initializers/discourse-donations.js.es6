import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import { popupAjaxError } from "discourse/lib/ajax-error";

function initializeDiscourseDonations(api) {
  
  // see app/assets/javascripts/discourse/lib/plugin-api
  // for the functions available via the api object

  api.modifyClass('controller:login', {
    actions: {
      login() {
        if (Discourse.SiteSettings.discourse_donations_subscription_required) {
          if (this.loginDisabled) {
            return;
          }
        
          if (Ember.isEmpty(this.loginName) || Ember.isEmpty(this.loginPassword)) {
            this.flash(I18n.t("login.blank_username_or_password"), "error");
            return;
          }

          this.set("loggingIn", true);

          ajax("/session", {
            type: "POST",
            data: {
              login: this.loginName,
              password: this.loginPassword,
              second_factor_token: this.secondFactorToken,
              second_factor_method: this.secondFactorMethod
            }
          }).then(
            result => {
              if (result && 
                  result.error && 
                  result.reason && 
                  result.reason === "no_active_subscription"){
                
                this.set("loggingIn", false);
                this.send("closeModal");
                bootbox.alert(result.error, function() {
                  DiscourseURL.redirectTo(result.redirect_to);
                });
                
              } else {
                if (result && result.error) {
                  this.set("loggingIn", false);
                  if (
                    result.reason === "invalid_second_factor" &&
                    !this.secondFactorRequired
                  ) {
                    document.getElementById("modal-alert").style.display = "none";

                    this.setProperties({
                      secondFactorRequired: true,
                      showLoginButtons: false,
                      backupEnabled: result.backup_enabled,
                      showSecondFactor: true
                    });

                    Ember.run.schedule("afterRender", () =>
                      document
                        .getElementById("second-factor")
                        .querySelector("input")
                        .focus()
                    );

                    return;
                  } else if (result.reason === "not_activated") {
                    this.send("showNotActivated", {
                      username: this.loginName,
                      sentTo: escape(result.sent_to_email),
                      currentEmail: escape(result.current_email)
                    });
                  } else if (result.reason === "suspended") {
                    this.send("closeModal");
                    bootbox.alert(result.error);
                  } else {
                    this.flash(result.error, "error");
                  }
                } else {
                  this.set("loggedIn", true);
                  // Trigger the browser's password manager using the hidden static login form:
                  const hiddenLoginForm = document.getElementById(
                    "hidden-login-form"
                  );
                  const applyHiddenFormInputValue = (value, key) => {
                    if (!hiddenLoginForm) return;

                    hiddenLoginForm.querySelector(`input[name=${key}]`).value = value;
                  };

                  const destinationUrl = $.cookie("destination_url");
                  const ssoDestinationUrl = $.cookie("sso_destination_url");

                  applyHiddenFormInputValue(this.loginName, "username");
                  applyHiddenFormInputValue(this.loginPassword, "password");

                  if (ssoDestinationUrl) {
                    $.removeCookie("sso_destination_url");
                    window.location.assign(ssoDestinationUrl);
                    return;
                  } else if (destinationUrl) {
                    // redirect client to the original URL
                    $.removeCookie("destination_url");

                    applyHiddenFormInputValue(destinationUrl, "redirect");
                  } else {
                    applyHiddenFormInputValue(window.location.href, "redirect");
                  }

                  if (hiddenLoginForm) {
                    if (
                      navigator.userAgent.match(/(iPad|iPhone|iPod)/g) &&
                      navigator.userAgent.match(/Safari/g)
                    ) {
                      // In case of Safari on iOS do not submit hidden login form
                      window.location.href = hiddenLoginForm.querySelector(
                        "input[name=redirect]"
                      ).value;
                    } else {
                      hiddenLoginForm.submit();
                    }
                  }
                  return;
                }
              }
            },
            e => {
              // Failed to login
              if (e.jqXHR && e.jqXHR.status === 429) {
                this.flash(I18n.t("login.rate_limit"), "error");
              } else if (!areCookiesEnabled()) {
                this.flash(I18n.t("login.cookies_error"), "error");
              } else {
                this.flash(I18n.t("login.error"), "error");
              }
              this.set("loggingIn", false);
            }
          );
        } else {
          this._super();
        }
      },
    }
  });
  
  api.modifyClass('controller:email-login', {
    actions: {
      finishLogin() {
        if (Discourse.SiteSettings.discourse_donations_subscription_required) {
          ajax({
            url: `/session/email-login/${this.model.token}`,
            type: "POST",
            data: {
              second_factor_token: this.secondFactorToken,
              second_factor_method: this.secondFactorMethod
            }
          })
            .then(result => {
              if (result && 
                  result.error && 
                  result.reason && 
                  result.reason === "no_active_subscription"){
                
                bootbox.alert(result.error, function() {
                  DiscourseURL.redirectTo(result.redirect_to);
                });
                
              } else {
                if (result.success) {
                  DiscourseURL.redirectTo("/");
                } else {
                  this.set("model.error", result.error);
                }
              }
            })
            .catch(popupAjaxError);
        } else {
          this._super();
        }
      }
    }
  });
  
}

export default {
  name: "discourse-donations",

  initialize() {
    withPluginApi("0.8.30", initializeDiscourseDonations);
  }
};
