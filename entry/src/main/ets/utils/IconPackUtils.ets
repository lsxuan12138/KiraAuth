import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError, zlib } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

export interface AegisIconDefinition {
  filename: string;
  category?: string;
  issuer?: string[];
}

export class AegisIconPack {
  public invalid: boolean = false;
  public onDevicePath: string = '';
  public uuid: string = '';
  public name: string = '';
  public version: number = 0;
  public icons: AegisIconDefinition[] = [];
  private iconMap: Map<string, string> = new Map();

  buildMap(): void {
    this.iconMap.clear();
    this.icons.forEach((icon) => {
      (icon.issuer ?? []).forEach((issuer) => {
        this.iconMap.set(issuer.toLowerCase(), icon.filename);
      });
    });
  }

  getIconPathByIssuer(issuer: string): string {
    const filename = this.iconMap.get(IconPackRegistry.normalizeIssuer(issuer));
    if (!filename) {
      return '';
    }
    return `file://${this.onDevicePath}/${filename}`;
  }

  getKey(): string {
    return this.onDevicePath;
  }
}

export class IconPackRegistry {
  private static readonly DEFAULT_PACK_KEY = 'default';
  private static readonly DEFAULT_ISSUERS: Set<string> = new Set([
    '1and1', '1password', '23andme', 'adafruit', 'adguard', 'adobe', 'airbnb', 'airbrake', 'airtable', 'allegropl',
    'alwaysdata', 'amazon', 'amazonwebservices', 'angellist', 'animebytes', 'anonaddy', 'apache', 'apple', 'appveyor',
    'arenanet', 'atlantic_net', 'atlassian', 'avm', 'backblaze', 'battlenet', 'betterment', 'binance', 'bitbucket',
    'bitcoin', 'bitdefender', 'bitfinex', 'bitmex', 'bitpanda', 'bitstamp', 'bittrex', 'bitwala', 'bitwarden',
    'blockchain_info', 'bugcrowd', 'cexio', 'church_tools', 'cisco', 'cloudflare', 'cloud_download', 'cobranded',
    'codegiant', 'coinbase', 'coinjar', 'computerbase', 'connectwise_manage', 'cozycloud', 'crowdin', 'dashlane',
    'debian', 'degiro', 'denic', 'deutsche_bahn', 'diaspora', 'digidentity', 'digital_ocean', 'discord', 'discourse',
    'disroot', 'docker', 'docusign', 'dreamhost', 'dropbox', 'drupal', 'electronic_arts', 'email', 'epic_games', 'etsy',
    'eveonline', 'evernote', 'facebook', 'faceit', 'fanatical', 'fastmail', 'figma', 'fingerprint', 'finnair',
    'firefox', 'flight_takeoff', 'floatplane', 'friendica', 'fritz', 'gamepad', 'gandi', 'git', 'gitea', 'github',
    'gitlab', 'gmx', 'godaddy', 'gogs', 'google', 'govuk', 'grav', 'greenhost', 'hackerone', 'heroku', 'hetzner',
    'hitbtc', 'hmrc', 'home_assistant', 'hover', 'humblebundle', 'hurricane_electric', 'ibm', 'iconomi', 'ifttt', 'ing',
    'instagram', 'inwx', 'itchio', 'jagex', 'jetbrains', 'joomla', 'keeper', 'kickstarter', 'kraken', 'kucoin',
    'lastpass', 'librenms', 'lichess', 'linkedin', 'linode', 'liqui', 'livelyme', 'lobsters', 'localbitcoins',
    'localmonero', 'login_gov', 'logmein', 'mailbox', 'mailchimp', 'mailcow', 'mailgun', 'mailru', 'mapbox', 'mastodon',
    'matomo', 'mega', 'mercadolibre', 'microsoft', 'microsoft_teams', 'migadu', 'miles_and_more', 'mint', 'miraheze',
    'mixer', 'mongodb', 'mvpsnet', 'namecheap', 'namecom', 'nas', 'netcup', 'nextcloud', 'nintendo', 'no_starch_press',
    'npm', 'oculus', 'office', 'okta', 'online', 'openvz', 'opnsense', 'orcid', 'origin', 'ovh', 'packet',
    'parsecgaming', 'passwordstate', 'patreon', 'paypal', 'paysafecard', 'paywithprivacy', 'pcloud', 'phabricator',
    'phpmyadmin', 'pluralsight', 'plurk', 'posteo', 'pretix', 'prey', 'private_internet_access', 'protonmail',
    'proxmox', 'pushover', 'pypi', 'python_anywhere', 'rackspace', 'reddit', 'revolt', 'ripe_ncc', 'ripio', 'robinhood',
    'rocketbeanstv', 'rockstar', 'rss', 'sap', 'scaleway', 'school', 'sciebo', 'sentry', 'sevdesk', 'skrill', 'slack',
    'snapchat', 'sophos', 'sourceforge', 'squarespace', 'standardnotes', 'starcitizen', 'steam', 'stripe', 'sync',
    'synology', 'teahub', 'teamviewer', 'terminal', 'tencent_cloud_services', 'todoalojamiento', 'transip', 'trello',
    'tumblr', 'turbotax', 'tutanota', 'tuwien_ac_at', 'twilio', 'twitch', 'twitter', 'uber', 'ubisoft', 'ubnt',
    'ubuntu_one', 'unity', 'uphold', 'usaa', 'vagrant_cloud', 'vexxhost', 'vk', 'vultr', 'wallabag', 'wallet',
    'wargaming', 'wasabi', 'weclapp', 'wikimedia', 'wordpress', 'workplace', 'xero', 'xerox', 'xing', 'yandex_money',
    'zapier', 'zendesk', 'zoho', 'zoom', 'feishu', 'nexus_mods'
  ]);

  static normalizeIssuer(issuer: string): string {
    return issuer.trim().toLowerCase().replaceAll(' ', '_');
  }

  static getDefaultPackKey(): string {
    return IconPackRegistry.DEFAULT_PACK_KEY;
  }

  static getIconPackDirectory(context: common.UIAbilityContext): string {
    return `${context.filesDir}/icon_packs`;
  }

  static ensureIconPackDirectory(context: common.UIAbilityContext): string {
    const dir = IconPackRegistry.getIconPackDirectory(context);
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir);
    }
    return dir;
  }

  static getDefaultIconPathByIssuer(issuer: string): string {
    const normalized = IconPackRegistry.normalizeIssuer(issuer);
    if (!IconPackRegistry.DEFAULT_ISSUERS.has(normalized)) {
      return '';
    }
    return `rawfile://icons/token_image_${normalized}.svg`;
  }

  static getIconPathByIssuer(issuer: string, selectedPackKey: string, installedPacks: AegisIconPack[]): string {
    if (!selectedPackKey || selectedPackKey === IconPackRegistry.DEFAULT_PACK_KEY) {
      return IconPackRegistry.getDefaultIconPathByIssuer(issuer);
    }

    const pack = installedPacks.find((item) => item.getKey() === selectedPackKey && !item.invalid);
    if (!pack) {
      return IconPackRegistry.getDefaultIconPathByIssuer(issuer);
    }

    return pack.getIconPathByIssuer(issuer);
  }

  static async loadInstalledPacks(context: common.UIAbilityContext): Promise<AegisIconPack[]> {
    const dir = IconPackRegistry.ensureIconPackDirectory(context);
    let folders: string[] = [];
    try {
      folders = await fs.listFile(dir);
    } catch (_) {
      return [];
    }

    const packs: AegisIconPack[] = [];
    for (const folder of folders) {
      const packPath = `${dir}/${folder}`;
      const pack = await IconPackRegistry.loadSinglePack(packPath);
      if (pack) {
        packs.push(pack);
      }
    }
    packs.sort((left, right) => left.name.localeCompare(right.name));
    return packs;
  }

  private static async loadSinglePack(packPath: string): Promise<AegisIconPack | undefined> {
    const packJsonPath = `${packPath}/pack.json`;
    if (!fs.accessSync(packJsonPath)) {
      const invalidPack = new AegisIconPack();
      invalidPack.invalid = true;
      invalidPack.onDevicePath = packPath;
      invalidPack.name = packPath.substring(packPath.lastIndexOf('/') + 1);
      return invalidPack;
    }

    try {
      const content = await IconPackRegistry.readTextFile(packJsonPath);
      const parsed = JSON.parse(content) as AegisIconPack;
      const pack = new AegisIconPack();
      pack.onDevicePath = packPath;
      pack.uuid = parsed.uuid ?? '';
      pack.name = parsed.name ?? packPath.substring(packPath.lastIndexOf('/') + 1);
      pack.version = parsed.version ?? 0;
      pack.icons = parsed.icons ?? [];
      pack.buildMap();
      return pack;
    } catch (_) {
      const invalidPack = new AegisIconPack();
      invalidPack.invalid = true;
      invalidPack.onDevicePath = packPath;
      invalidPack.name = packPath.substring(packPath.lastIndexOf('/') + 1);
      return invalidPack;
    }
  }

  static async importFromZip(context: common.UIAbilityContext, zipUri: string): Promise<void> {
    const dir = IconPackRegistry.ensureIconPackDirectory(context);
    const zipFile = fs.openSync(zipUri, fs.OpenMode.READ_ONLY);
    const zipPath = zipFile.path;
    const zipName = zipPath.substring(zipPath.lastIndexOf('/') + 1);
    await fs.close(zipFile.fd);

    const baseName = zipName.endsWith('.zip') ? zipName.substring(0, zipName.length - 4) : zipName;
    let targetDir = `${dir}/${baseName}`;
    let suffix = 1;
    while (fs.accessSync(targetDir)) {
      targetDir = `${dir}/${baseName}_${suffix++}`;
    }

    fs.mkdirSync(targetDir);
    try {
      await zlib.decompressFile(zipPath, targetDir);
    } catch (error) {
      IconPackRegistry.safeRemoveDir(targetDir);
      throw new Error(IconPackRegistry.formatImportError(error as Object));
    }

    const pack = await IconPackRegistry.loadSinglePack(targetDir);
    if (!pack || pack.invalid) {
      IconPackRegistry.safeRemoveDir(targetDir);
      throw new Error('Invalid icon pack');
    }
  }

  static async pickZipFiles(context: common.UIAbilityContext): Promise<string[]> {
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 5;
    options.fileSuffixFilters = ['.zip'];
    const viewPicker = new picker.DocumentViewPicker(context);
    return viewPicker.select(options);
  }

  static async removePack(pack: AegisIconPack): Promise<void> {
    if (!pack.onDevicePath) {
      return;
    }
    try {
      await fs.rmdir(pack.onDevicePath);
    } catch (_) {
      IconPackRegistry.safeRemoveDir(pack.onDevicePath);
    }
  }

  private static safeRemoveDir(path: string): void {
    if (!fs.accessSync(path)) {
      return;
    }
    try {
      fs.rmdirSync(path);
    } catch (_) {
      try {
        const files = fs.listFileSync(path);
        files.forEach((name) => {
          const child = `${path}/${name}`;
          try {
            fs.unlinkSync(child);
          } catch (_) {
            IconPackRegistry.safeRemoveDir(child);
          }
        });
        fs.rmdirSync(path);
      } catch (_) {
      }
    }
  }

  private static async readTextFile(uri: string): Promise<string> {
    const file = await fs.open(uri, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      const readBytes = fs.readSync(file.fd, buffer);
      return new util.TextDecoder().decodeToString(new Uint8Array(buffer.slice(0, readBytes)));
    } finally {
      await fs.close(file.fd);
    }
  }

  static formatImportError(error: Object): string {
    const businessError = error as BusinessError;
    if (businessError && businessError.message) {
      return businessError.message;
    }
    return `${error}`;
  }
}


