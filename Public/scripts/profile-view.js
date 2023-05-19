function getBlobLink(did, blob, baseUrl = 'https://bsky.social') {
  if (blob == null) return null

  const src = new URL('/xrpc/com.atproto.sync.getBlob', baseUrl);
  src.searchParams.set('did', did);

  if (blob.$type === 'blob') {
    src.searchParams.set('cid', blob.ref.$link);
  } else {
    src.searchParams.set('cid', blob.cid);
  }

  return {
    src,
    mimeType: blob.mimeType,
  }
};

export async function getRecord(did, baseUrl) {
  const url = new URL('/xrpc/com.atproto.repo.getRecord', baseUrl);
  url.searchParams.set('repo', did);
  url.searchParams.set('collection', 'app.bsky.actor.profile');
  url.searchParams.set('rkey', 'self');

  const body = await fetch(url).then(res => {
    const json = res.json();
    if (res.status >= 300) {
      throw json
    }
    return json
  });

  const {
    displayName,
    description,
    avatar,
    banner,
  } = body.value;

  return {
    displayName,
    description,
    avatar: getBlobLink(did, avatar, baseUrl),
    banner: getBlobLink(did, banner, baseUrl),
  }
};

export async function describeRepo(repo, baseUrl) {
  const url = new URL('/xrpc/com.atproto.repo.describeRepo', baseUrl);
  url.searchParams.set('repo', repo);

  const body = await fetch(url).then(res => {
    const json = res.json();
    if (res.status >= 300) {
      throw json
    }
    return json
  });

  const {
    handle,
    did,
    didDoc,
    collections,
    handleIsCorrect,
  } = body;

  return {
    did: did,
    handle: handle,
    baseUrl: didDoc.service.find(x => x.type === 'AtprotoPersonalDataServer')?.serviceEndpoint ?? baseUrl,
    hasProfile: collections.includes('app.bsky.actor.profile'),
    handleIsCorrect,
  }
}

export class ProfileModal extends HTMLElement {
  constructor() {
    super();

    const shadowRoot = this.attachShadow({mode: 'open', slotAssignment: 'manual'});

    const style = shadowRoot.appendChild(document.createElement('style'));

    style.textContent = `
:host {
  display: none;
}
:host([open]) {
  display: block;
  position: fixed;
  z-index: 10000;
  inset: 0;
  background: rgb(222 222 222 / .8);
}
:host > div {
  margin: 10vh 10vw;
  padding: 1rem;
  display: grid;
  grid-template-columns: 6rem calc(80vw - 9rem);
  gap: 1rem;
  background: #fff;
}
@media (prefers-color-scheme: dark) {
  :host([open]) {
    background: rgb(32 32 32 / .8);
  }
  :host > div {
    background: #333;
  }
}
slot[name=banner]::slotted(img) {
  width: 100%;
  grid-column: span 2;
}
slot[name=avatar]::slotted(img) {
  width: 100%;
  grid-column-start: 1;
}
dl {
  grid-column-start: 2;
  display: grid;
  grid-template-columns: 4rem 1fr;
  gap: .5rem 1rem;
}
dl > dt {
  font-weight: bold;
  text-align: right;
  grid-column-start: 1;
}
dl > dd {
  margin: 0;
  grid-column-start: 2;
}
`;

    const div = shadowRoot.appendChild(document.createElement('div'));
    this.bannerSlot = div.appendChild(document.createElement('slot'));
    this.bannerSlot.name = 'banner'
    this.avatarSlot = div.appendChild(document.createElement('slot'));
    this.avatarSlot.name = 'avatar'
    const dl = div.appendChild(document.createElement('dl'));
    const name = dl.appendChild(document.createElement('dt'));
    name.textContent = 'Name';
    this.displayNameSlot = dl.appendChild(document.createElement('slot'));
    const bio = dl.appendChild(document.createElement('dt'));
    bio.textContent = 'Bio';
    this.descriptionSlot = dl.appendChild(document.createElement('slot'));

    this.displayName = document.createElement('dd');
    this.description = document.createElement('dd');
    this.avatar = new Image();
    this.avatar.alt = 'avatar';
    this.banner = new Image();
    this.banner.alt = 'banner';
  }

  connectedCallback() {
    this.append(this.displayName, this.description, this.avatar, this.banner);
    this.addEventListener('click', () => this.close());
  }

  open({displayName, description, avatar, banner}) {
    if (displayName == null) {
      this.displayNameSlot.assign();
    } else {
      this.displayName.textContent = displayName;
      this.displayNameSlot.assign(this.displayName);
    }
    if (description == null) {
      this.descriptionSlot.assign();
    } else {
      this.description.textContent = description;
      this.descriptionSlot.assign(this.description);
    }
    if (avatar == null) {
      this.avatarSlot.assign();
    } else {
      this.avatar.src = avatar.src;
      this.avatarSlot.assign(this.avatar);
    }
    if (banner == null) {
      this.bannerSlot.assign();
    } else {
      this.banner.src = banner.src;
      this.bannerSlot.assign(this.banner);
    }
    this.setAttribute('open', '');
  }

  close() {
    this.removeAttribute('open');
  }
}
window.customElements.define('profile-modal', ProfileModal);
