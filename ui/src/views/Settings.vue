<!--
  Copyright (C) 2022 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("settings.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-configuration')"
          :description="error.getConfiguration"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <cv-text-input
              :label="$t('settings.backuppc_fqdn')"
              placeholder="backuppc.example.org"
              v-model.trim="host"
              class="mg-bottom"
              :invalid-message="$t(error.host)"
              :disabled="loading.getConfiguration || loading.configureModule"
              ref="host"
            >
            </cv-text-input>
            <cv-toggle
              value="letsEncrypt"
              :label="$t('settings.lets_encrypt')"
              v-model="isLetsEncryptEnabled"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="mg-bottom"
            >
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </cv-toggle>
            <cv-toggle
              value="httpToHttps"
              :label="$t('settings.http_to_https')"
              v-model="isHttpToHttpsEnabled"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="mg-bottom"
            >
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </cv-toggle>
            <NsComboBox
              v-model.trim="ldap_domain"
              :autoFilter="true"
              :autoHighlight="true"
              :title="$t('settings.user_domains_list')"
              :label="$t('settings.choose_user_domain')"
              :options="user_domains_list"
              :userInputLabel="core.$t('settings.choose_user_domain')"
              :acceptUserInput="false"
              :showItemType="true"
              :invalid-message="$t(error.ldap_domain)"
              :disabled="loading.getConfiguration || loading.configureModule"
              tooltipAlignment="start"
              tooltipDirection="top"
              ref="ldap_domain"
            >
              <template slot="tooltip">
                {{ $t("settings.choose_the_user_domain_to_use") }}
              </template>
            </NsComboBox>
            <template v-if="ldap_domain === 'basic'">
              <cv-text-input
                :label="$t('settings.auth_username')"
                placeholder="backuppc"
                v-model.trim="auth_user"
                class="mg-bottom"
                :invalid-message="$t(error.auth_user)"
                :disabled="loading.getConfiguration || loading.configureModule"
                ref="auth_user"
              >
              </cv-text-input>
              <cv-text-input
                :label="$t('settings.auth_password')"
                placeholder="Nethesis,1234"
                type="password"
                v-model.trim="auth_pass"
                class="mg-bottom"
                :invalid-message="$t(error.auth_pass)"
                :disabled="loading.getConfiguration || loading.configureModule"
                ref="auth_pass"
              >
              </cv-text-input>
            </template>
            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.configure-module')"
                  :description="error.configureModule"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="loading.getConfiguration || loading.configureModule"
              >{{ $t("settings.save") }}</NsButton
            >
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

export default {
  name: "Settings",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "settings",
      },
      urlCheckInterval: null,
      host: "",
      auth_user: "backuppc",
      auth_pass: "Nethesis,1234",
      ldap_domain: "",
      user_domains_list: [],
      isLetsEncryptEnabled: false,
      isHttpToHttpsEnabled: true,
      loading: {
        getConfiguration: false,
        configureModule: false,
      },
      error: {
        getConfiguration: "",
        configureModule: "",
        host: "",
        lets_encrypt: "",
        http2https: "",
        auth_user: "",
        auth_pass: "",
        ldap_domain: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
  },
  created() {
    this.getConfiguration();
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  methods: {
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getConfigurationAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
        return;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.host = config.host;
      this.isLetsEncryptEnabled = config.lets_encrypt;
      this.isHttpToHttpsEnabled = config.http2https;
      this.auth_user = config.auth_user;
      this.auth_pass = config.auth_pass;
      this.$nextTick(() => {
        this.ldap_domain = config.ldap_domain;
      });
      this.user_domains_list = config.user_domains_list;
      this.user_domains_list.unshift({
        name: "basic",
        label: this.$t("settings.basic_authentication"),
        value: "basic",
      });
      this.loading.getConfiguration = false;
      this.focusElement("host");
    },
    validateConfigureModule() {
      this.clearErrors(this);

      let isValidationOk = true;
      if (!this.host) {
        this.error.host = "common.required";

        if (isValidationOk) {
          this.focusElement("host");
        }
        isValidationOk = false;
      }
      if (!this.ldap_domain) {
        this.error.ldap_domain = "common.required";

        if (isValidationOk) {
          this.focusElement("ldap_domain");
        }
        isValidationOk = false;
      }
      if (this.ldap_domain === "basic" && !this.auth_user) {
        this.error.auth_user = "common.required";

        if (isValidationOk) {
          this.focusElement("auth_user");
        }
        isValidationOk = false;
      }
      if (this.ldap_domain === "basic" && !this.auth_pass) {
        this.error.auth_pass = "common.required";

        if (isValidationOk) {
          this.focusElement("auth_user");
        }
        isValidationOk = false;
      }
      // verify the password is > 8 characters
      if (this.auth_pass && this.auth_pass.length < 8) {
        this.error.auth_pass = "common.password_length";

        if (isValidationOk) {
          this.focusElement("auth_pass");
        }
        isValidationOk = false;
      }
      return isValidationOk;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusAlreadySet = false;

      for (const validationError of validationErrors) {
        const param = validationError.parameter;
        // set i18n error message
        this.error[param] = this.$t("settings." + validationError.error);

        if (!focusAlreadySet) {
          this.focusElement(param);
          focusAlreadySet = true;
        }
      }
    },
    async configureModule() {
      this.error.test_imap = false;
      this.error.test_smtp = false;
      const isValidationOk = this.validateConfigureModule();
      if (!isValidationOk) {
        return;
      }

      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            host: this.host,
            lets_encrypt: this.isLetsEncryptEnabled,
            http2https: this.isHttpToHttpsEnabled,
            auth_user: this.auth_user,
            auth_pass: this.auth_pass,
            ldap_domain: this.ldap_domain,
          },
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;

      // reload configuration
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}

.maxwidth {
  max-width: 38rem;
}
</style>