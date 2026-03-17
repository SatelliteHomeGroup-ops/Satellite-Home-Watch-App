const ALLOWED_ACCESS_ROLES = new Set(['corporate', 'manager']);
const INVITEABLE_BY_ROLE = {
  corporate: ['corporate', 'manager', 'inspector', 'customer'],
  manager: ['customer'],
};

const state = {
  supabase: null,
  profile: null,
  invitations: [],
  invitationPropertiesMap: new Map(),
  properties: [],
  filters: {
    search: '',
    status: 'all',
    role: 'all',
  },
};

const elements = {
  sidebar: document.getElementById('adminSidebar'),
  roleBadge: document.getElementById('roleBadge'),
  userAvatar: document.getElementById('userAvatar'),
  restrictedState: document.getElementById('restrictedState'),
  workspace: document.getElementById('invitationWorkspace'),
  statPending: document.getElementById('statPending'),
  statAccepted: document.getElementById('statAccepted'),
  statExpired: document.getElementById('statExpired'),
  statRevoked: document.getElementById('statRevoked'),
  searchInput: document.getElementById('searchInput'),
  statusFilter: document.getElementById('statusFilter'),
  roleFilter: document.getElementById('roleFilter'),
  openInviteModalBtn: document.getElementById('openInviteModalBtn'),
  tbody: document.getElementById('invitationsTbody'),
  empty: document.getElementById('tableEmpty'),
  modalShell: document.getElementById('inviteModalShell'),
  inviteForm: document.getElementById('inviteForm'),
  closeModalBtn: document.getElementById('closeModalBtn'),
  cancelInviteBtn: document.getElementById('cancelInviteBtn'),
  submitInviteBtn: document.getElementById('submitInviteBtn'),
  inviteRoleSelect: document.getElementById('inviteRoleSelect'),
  propertyField: document.getElementById('propertyField'),
  propertySelect: document.getElementById('propertySelect'),
};

function resolveSupabaseConfig() {
  const appConfig = window.APP_CONFIG || window.__APP_CONFIG__ || {};
  return {
    url:
      window.SUPABASE_URL ||
      window.__SUPABASE_URL__ ||
      appConfig.supabaseUrl ||
      appConfig.SHW_SUPABASE_URL ||
      '',
    anonKey:
      window.SUPABASE_ANON_KEY ||
      window.__SUPABASE_ANON_KEY__ ||
      appConfig.supabaseAnonKey ||
      appConfig.SHW_SUPABASE_ANON_KEY ||
      '',
  };
}

function createSupabaseClient() {
  const { url, anonKey } = resolveSupabaseConfig();
  if (!url || !anonKey) {
    throw new Error('Missing Supabase configuration for this environment.');
  }
  return window.supabase.createClient(url, anonKey);
}

function sanitizeRole(role) {
  return (role || '').toLowerCase().trim();
}

function fullName(profile) {
  const merged = `${profile.first_name || ''} ${profile.last_name || ''}`.trim();
  return merged || profile.full_name || profile.email || 'User';
}

function initialsFromName(name) {
  const parts = String(name || '')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2);
  return parts.map((p) => p[0]?.toUpperCase() || '').join('') || 'U';
}

function formatDate(value) {
  if (!value) return '—';
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(new Date(value));
}

function escapeHTML(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function openModal() {
  elements.modalShell.style.display = 'flex';
  elements.modalShell.setAttribute('aria-hidden', 'false');
}

function closeModal() {
  elements.modalShell.style.display = 'none';
  elements.modalShell.setAttribute('aria-hidden', 'true');
  elements.inviteForm.reset();
  updateRoleDependentFields();
  clearErrors();
}

function clearErrors() {
  elements.inviteForm.querySelectorAll('[data-error]').forEach((el) => {
    el.textContent = '';
  });
}

function setError(fieldName, message) {
  const target = elements.inviteForm.querySelector(`[data-error="${fieldName}"]`);
  if (target) {
    target.textContent = message;
  }
}

function updateRoleBadge(role) {
  elements.roleBadge.classList.remove('corporate', 'manager');
  elements.roleBadge.classList.add(role === 'manager' ? 'manager' : 'corporate');
  elements.roleBadge.textContent = role;
}

function renderTopbarProfile(profile) {
  const name = fullName(profile);
  const initials = initialsFromName(name);
  elements.userAvatar.textContent = initials;
  updateRoleBadge(sanitizeRole(profile.role));
}

function setSession(profile) {
  const role = sanitizeRole(profile.role);
  const name = fullName(profile);
  window.ADMIN_SESSION = {
    userId: profile.id,
    role,
    name,
    initials: initialsFromName(name),
  };
}

function renderSidebar(profile) {
  elements.sidebar.style.display = 'block';

  if (typeof window.renderAdminSidebar === 'function') {
    window.renderAdminSidebar(elements.sidebar, {
      currentPage: 'invitations',
      profile,
    });
    return;
  }

  const wrapper = document.createElement('div');
  const heading = document.createElement('h2');
  const name = document.createElement('p');

  heading.textContent = 'Admin';
  name.textContent = fullName(profile);

  wrapper.appendChild(heading);
  wrapper.appendChild(name);

  elements.sidebar.replaceChildren(wrapper);
}

function buildRoleOptions(profileRole) {
  const options = INVITEABLE_BY_ROLE[profileRole] || [];
  elements.inviteRoleSelect.innerHTML = ['<option value="">Select role</option>']
    .concat(options.map((role) => `<option value="${role}">${role[0].toUpperCase()}${role.slice(1)}</option>`))
    .join('');
}

function renderPropertyOptions() {
  elements.propertySelect.innerHTML = state.properties
    .map((p) => `<option value="${p.id}">${p.name || '(Unnamed property)'}</option>`)
    .join('');
}

function updateRoleDependentFields() {
  const selectedRole = sanitizeRole(elements.inviteRoleSelect.value);
  const showProperties = selectedRole === 'customer';
  elements.propertyField.style.display = showProperties ? 'flex' : 'none';

  if (!showProperties) {
    Array.from(elements.propertySelect.options).forEach((option) => {
      option.selected = false;
    });
  }
}

function filteredInvitations() {
  const search = state.filters.search.toLowerCase();
  return state.invitations.filter((invite) => {
    if (state.filters.status !== 'all' && invite.status !== state.filters.status) return false;
    if (state.filters.role !== 'all' && invite.role !== state.filters.role) return false;

    if (search) {
      const combined = [invite.email, `${invite.first_name || ''} ${invite.last_name || ''}`]
        .join(' ')
        .toLowerCase();
      return combined.includes(search);
    }

    return true;
  });
}

function calculateStats() {
  const stats = { pending: 0, accepted: 0, expired: 0, revoked: 0 };
  for (const invite of state.invitations) {
    if (stats[invite.status] !== undefined) {
      stats[invite.status] += 1;
    }
  }

  elements.statPending.textContent = String(stats.pending);
  elements.statAccepted.textContent = String(stats.accepted);
  elements.statExpired.textContent = String(stats.expired);
  elements.statRevoked.textContent = String(stats.revoked);
}

function statusPill(status) {
  return `<span class="status-pill status-${status}">${status}</span>`;
}

function propertyNamesForInvitation(invitationId) {
  return state.invitationPropertiesMap.get(invitationId) || [];
}

function renderTable() {
  const rows = filteredInvitations();
  elements.tbody.innerHTML = '';

  if (!rows.length) {
    elements.empty.style.display = 'block';
    return;
  }

  elements.empty.style.display = 'none';

  for (const invite of rows) {
    const properties = propertyNamesForInvitation(invite.id);
    const propertiesCell = properties.length ? properties.join(', ') : '—';
    const safeName = `${invite.first_name || ''} ${invite.last_name || ''}`.trim() || '—';

    const escapedEmail = escapeHTML(invite.email);
    const escapedName = escapeHTML(safeName);
    const escapedRole = escapeHTML(invite.role);
    const escapedProperties = escapeHTML(propertiesCell);

    const row = document.createElement('tr');
    row.innerHTML = `
      <td>${escapedEmail}</td>
      <td>${escapedName}</td>
      <td style="text-transform:capitalize;">${escapedRole}</td>
      <td>${escapedProperties}</td>
      <td>${statusPill(invite.status)}</td>
      <td>${formatDate(invite.sent_at)}</td>
      <td>${formatDate(invite.expires_at)}</td>
      <td>
        <div class="table-actions">
          <button class="btn btn-subtle" data-action="resend" data-id="${invite.id}" ${invite.status !== 'pending' ? 'disabled' : ''}>Resend</button>
          <button class="btn btn-danger" data-action="revoke" data-id="${invite.id}" ${invite.status === 'revoked' ? 'disabled' : ''}>Revoke</button>
        </div>
      </td>
    `;

    elements.tbody.appendChild(row);
  }
}

async function loadProfile() {
  const { data: authData, error: authError } = await state.supabase.auth.getSession();
  if (authError) throw authError;

  const session = authData?.session;
  if (!session?.user?.id) {
    window.location.href = 'auth.html';
    return null;
  }

  const { data: profile, error: profileError } = await state.supabase
    .from('profiles')
    .select('id, role, first_name, last_name, full_name')
    .eq('id', session.user.id)
    .single();

  if (profileError || !profile) {
    window.location.href = 'auth.html';
    return null;
  }

  profile.email = session.user.email || '';
  return profile;
}

async function loadProperties() {
  const { data, error } = await state.supabase
    .from('properties')
    .select('id, name')
    .order('name', { ascending: true });

  if (error) throw error;
  state.properties = data || [];
}

async function loadInvitations() {
  const { data: invitations, error } = await state.supabase
    .from('invitations')
    .select('id, email, first_name, last_name, role, status, sent_at, expires_at')
    .order('sent_at', { ascending: false });

  if (error) throw error;
  state.invitations = invitations || [];

  const invitationIds = state.invitations.map((invite) => invite.id);
  if (!invitationIds.length) {
    state.invitationPropertiesMap = new Map();
    return;
  }

  const { data: joinRows, error: joinError } = await state.supabase
    .from('invitation_properties')
    .select('invitation_id, property:properties(name)')
    .in('invitation_id', invitationIds);

  if (joinError) throw joinError;

  const map = new Map();
  for (const row of joinRows || []) {
    const name = row.property?.name || '(Unnamed property)';
    if (!map.has(row.invitation_id)) map.set(row.invitation_id, []);
    map.get(row.invitation_id).push(name);
  }

  state.invitationPropertiesMap = map;
}

async function sendInvitation(payload) {
  const { error } = await state.supabase.functions.invoke('invitation-workflow', {
    body: payload,
  });

  if (error) throw error;
}

async function resendInvitation(invitationId) {
  const { error } = await state.supabase.functions.invoke('invitation-workflow', {
    body: {
      action: 'resend',
      invitation_id: invitationId,
    },
  });

  if (error) throw error;
}

async function revokeInvitation(invitationId) {
  const now = new Date().toISOString();
  const { error } = await state.supabase
    .from('invitations')
    .update({ status: 'revoked', revoked_at: now })
    .eq('id', invitationId);

  if (error) throw error;
}

function modalPayload() {
  const formData = new FormData(elements.inviteForm);
  const role = sanitizeRole(formData.get('role'));
  const email = String(formData.get('email') || '').trim().toLowerCase();
  const expirationDays = Number(formData.get('expiration_days') || 14);
  const propertyIds = Array.from(elements.propertySelect.selectedOptions).map((o) => o.value);

  clearErrors();
  let valid = true;

  if (!email) {
    setError('email', 'Email is required.');
    valid = false;
  }

  if (!role) {
    setError('role', 'Role is required.');
    valid = false;
  }

  if (role === 'customer' && propertyIds.length === 0) {
    setError('property_ids', 'Select at least one property for customer invitations.');
    valid = false;
  }

  if (!valid) return null;

  return {
    action: 'send',
    first_name: String(formData.get('first_name') || '').trim(),
    last_name: String(formData.get('last_name') || '').trim(),
    email,
    role,
    property_ids: role === 'customer' ? propertyIds : [],
    expires_at: new Date(Date.now() + expirationDays * 24 * 60 * 60 * 1000).toISOString(),
    notes: String(formData.get('notes') || '').trim(),
  };
}

function wireEventHandlers() {
  elements.searchInput.addEventListener('input', (event) => {
    state.filters.search = event.target.value.trim();
    renderTable();
  });

  elements.statusFilter.addEventListener('change', (event) => {
    state.filters.status = event.target.value;
    renderTable();
  });

  elements.roleFilter.addEventListener('change', (event) => {
    state.filters.role = event.target.value;
    renderTable();
  });

  elements.openInviteModalBtn.addEventListener('click', openModal);
  elements.closeModalBtn.addEventListener('click', closeModal);
  elements.cancelInviteBtn.addEventListener('click', closeModal);
  elements.inviteRoleSelect.addEventListener('change', updateRoleDependentFields);

  elements.modalShell.addEventListener('click', (event) => {
    if (event.target === elements.modalShell) {
      closeModal();
    }
  });

  elements.inviteForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const payload = modalPayload();
    if (!payload) return;

    elements.submitInviteBtn.disabled = true;
    try {
      await sendInvitation(payload);
      closeModal();
      await loadInvitations();
      calculateStats();
      renderTable();
    } catch (error) {
      alert(error.message || 'Unable to send invitation.');
    } finally {
      elements.submitInviteBtn.disabled = false;
    }
  });

  elements.tbody.addEventListener('click', async (event) => {
    const button = event.target.closest('button[data-action]');
    if (!button) return;

    const { action, id } = button.dataset;
    if (!id) return;

    button.disabled = true;
    try {
      if (action === 'resend') {
        await resendInvitation(id);
      } else if (action === 'revoke') {
        await revokeInvitation(id);
      }

      await loadInvitations();
      calculateStats();
      renderTable();
    } catch (error) {
      alert(error.message || 'Action failed.');
      button.disabled = false;
    }
  });
}

async function initialize() {
  try {
    state.supabase = createSupabaseClient();
    const profile = await loadProfile();
    if (!profile) return;

    state.profile = profile;
    const role = sanitizeRole(profile.role);

    setSession(profile);
    renderSidebar(profile);
    renderTopbarProfile(profile);

    if (!ALLOWED_ACCESS_ROLES.has(role)) {
      elements.restrictedState.style.display = 'block';
      elements.workspace.style.display = 'none';
      return;
    }

    elements.restrictedState.style.display = 'none';
    elements.workspace.style.display = 'block';

    buildRoleOptions(role);
    await Promise.all([loadProperties(), loadInvitations()]);
    renderPropertyOptions();
    calculateStats();
    renderTable();
    wireEventHandlers();
    updateRoleDependentFields();
  } catch (error) {
    console.error(error);
    alert(error.message || 'Initialization failed.');
  }
}

const APP_CONFIG_WAIT_TIMEOUT_MS = 5000;
const APP_CONFIG_POLL_INTERVAL_MS = 100;

function hasSupabaseConfig() {
  return Boolean(window.__APP_CONFIG__?.supabaseUrl && window.__APP_CONFIG__?.supabaseAnonKey);
}

function waitForAppConfig() {
  if (hasSupabaseConfig()) {
    return Promise.resolve();
  }

  return new Promise((resolve, reject) => {
    const startedAt = Date.now();
    let settled = false;

    const cleanup = () => {
      settled = true;
      window.removeEventListener('app-config-ready', onConfigReady);
      clearInterval(pollTimer);
    };

    const resolveIfConfigReady = () => {
      if (!hasSupabaseConfig() || settled) {
        return;
      }

      cleanup();
      resolve();
    };

    const onConfigReady = () => {
      resolveIfConfigReady();
    };

    window.addEventListener('app-config-ready', onConfigReady);

    const pollTimer = setInterval(() => {
      resolveIfConfigReady();

      if (Date.now() - startedAt >= APP_CONFIG_WAIT_TIMEOUT_MS && !settled) {
        cleanup();
        reject(new Error('Timed out waiting for app config to load.'));
      }
    }, APP_CONFIG_POLL_INTERVAL_MS);

    resolveIfConfigReady();
  });
}

waitForAppConfig()
  .then(() => initialize())
  .catch((error) => {
    console.error(error);
    alert(error.message || 'Initialization failed.');
  });
