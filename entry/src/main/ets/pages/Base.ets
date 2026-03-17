import { systemDateTime } from '@kit.BasicServicesKit';
import { ComponentContent } from '@kit.ArkUI';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer, JSON, uri, util } from '@kit.ArkTS';
import { distributedKVStore } from '@kit.ArkData';
import { getLocalizedString, kvManager } from '../entryability/EntryAbility';
import * as steamapi from './steamapi/custom';
import * as steam2faapi from './steamapi/service_twofactor';
import * as googleapi from './googleapi/otpauth_migrate';

export let DefaultToastDuration = 5000


export class AuthData {
  uuid: string = ""
  order: number = 0
  alias: string = ""
  issuer: string = ""
  account: string = ""
  secret: string = ""
  digits: number = 6
  password: string = ""
  external: string = ""
  tokenIconPath: string = ""
}

export class SteamAuthData {
  public accountName: string = ""
  public steamID: string = ""
  public serialNumber: string = ""
  public revocationCode: string = ""
  public sharedSecret: string = ""
  public tokenGID: string = ""
  public identitySecret: string = ""
  public uri: string = ""
  public deviceID: string = ""
  public secret1: string = ""
  public accessToken: string = ""
  public refreshToken: string = ""
}

export class SteamAccountData {
  auth?: steamapi.CAuthentication_BeginAuthSessionViaCredentials_Response
  confirmation?: steamapi.CAuthentication_AllowedConfirmation
  tokens?: steamapi.CAuthentication_PollAuthSessionStatus_Response
  deviceId: string = ""
  authenticator?: steam2faapi.CTwoFactor_AddAuthenticator_Response
  finalizeAuthenticator?: steam2faapi.CTwoFactor_FinalizeAddAuthenticator_Response
  status?: steam2faapi.CTwoFactor_Status_Response
  account?: steam2faapi.CTwoFactor_RemoveAuthenticatorViaChallengeContinue_Response
}

export class AuthDataStore {
  public kvStore?: distributedKVStore.DeviceKVStore
  public items: AuthData[] = []
  private onChanged: (items: AuthData[]) => void

  public constructor(onChanged: (items: AuthData[]) => void) {
    this.onChanged = onChanged
    kvManager.getKVStore("authdata", {
      createIfMissing: true,
      securityLevel: distributedKVStore.SecurityLevel.S2,
    }, (err: Error, store: distributedKVStore.DeviceKVStore) => {
      if (err) {
        throw new Error(err.message)
      }
      this.kvStore = store
      this.kvStore.getEntries("/data/auth/", (_entryErr, data) => {
        const seen = new Set<string>()
        for (let i = 0; i < data.length; i++) {
          let authdata = JSON.parse(data[i].value.value as string) as AuthData
          if (authdata.uuid == undefined || authdata.uuid == "") {
            authdata.uuid = AuthDataStore.computeAuthUuid(authdata.issuer, authdata.account, authdata.secret)
          }
          if (authdata.order == undefined) {
            authdata.order = i
          }
          authdata.password = this.generatePassword(authdata)
          if (seen.has(authdata.uuid)) {
            continue
          }
          seen.add(authdata.uuid)
          this.items.push(authdata)
        }
        this.items.sort((a, b) => a.order - b.order)
        this.notifyChanged()
      })
    })
  }

  private notifyChanged(): void {
    this.onChanged([...this.items])
  }

  private buildStorageKey(uuid: string): string {
    return `/data/auth/${uuid}`
  }

  private static computeHash(input: string, seed: number): number {
    let hash = (2166136261 ^ seed) >>> 0
    for (let i = 0; i < input.length; i++) {
      hash ^= input.charCodeAt(i)
      hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24)
      hash >>>= 0
    }
    return hash >>> 0
  }

  private static padHex(value: number): string {
    let hex = value.toString(16)
    while (hex.length < 8) {
      hex = `0${hex}`
    }
    return hex
  }

  static computeAuthUuid(issuer: string, account: string, secret: string): string {
    const source = `${issuer.trim().toLowerCase()}\n${account.trim().toLowerCase()}\n${secret.trim().toUpperCase()}`
    const combined = `${AuthDataStore.padHex(AuthDataStore.computeHash(source, 17))}` +
      `${AuthDataStore.padHex(AuthDataStore.computeHash(source, 31))}` +
      `${AuthDataStore.padHex(AuthDataStore.computeHash(source, 47))}` +
      `${AuthDataStore.padHex(AuthDataStore.computeHash(source, 61))}`
    return `${combined.substring(0, 8)}-${combined.substring(8, 12)}-${combined.substring(12, 16)}-` +
      `${combined.substring(16, 20)}-${combined.substring(20, 32)}`
  }

  private persistAuthItem(item: AuthData): void {
    let authString = JSON.stringify(item)
    this.kvStore?.put(this.buildStorageKey(item.uuid), authString)
  }

  private containsUuid(uuid: string): boolean {
    return this.findAuthItem(uuid) >= 0
  }

  private appendAuthItem(item: AuthData): boolean {
    if (this.containsUuid(item.uuid)) {
      return false
    }
    item.order = this.items.length
    item.password = this.generatePassword(item)
    this.persistAuthItem(item)
    this.items.push(item)
    return true
  }

  private reindexOrders(persist: boolean = true): void {
    for (let i = 0; i < this.items.length; i++) {
      this.items[i].order = i
      if (persist) {
        this.persistAuthItem(this.items[i])
      }
    }
  }

  static base32Decode(secret: string): Uint8Array {
    let base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
    let base32Lookup: Record<string, number> = {}
    for (let i = 0; i < base32Chars.length; i++) {
      base32Lookup[base32Chars[i]] = i
    }
    let bits: string[] = []
    for (let i = 0; i < secret.length; i++) {
      let value = base32Lookup[secret[i].toUpperCase()]
      bits.push(value.toString(2).padStart(5, '0'))
    }
    let bitsString = bits.join('')
    let bytes: Uint8Array = new Uint8Array(bitsString.length / 8)
    for (let i = 0; i < bits.length; i++) {
      bytes[i] = parseInt(bitsString.slice(i * 8, i * 8 + 8), 2)
    }
    return bytes
  }

  static base32Encode(data: Uint8Array): string {
    const base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
    let bits = ''
    let result = ''

    for (let i = 0; i < data.length; i++) {
      bits += data[i].toString(2).padStart(8, '0')
    }

    let index = 0
    while (index < bits.length) {
      const chunk = bits.slice(index, index + 5).padEnd(5, '0')
      const byte = parseInt(chunk, 2)
      result += base32Chars.charAt(byte)
      index += 5
    }

    const padCount = (8 - (result.length % 8)) % 8;
    return result + '='.repeat(padCount);
  }

  static numToUint8Array(num: number): Uint8Array {
    let arr = new Uint8Array(8);
    for (let i = 7; i >= 0; i--) {
      arr[i] = num & 0xff;
      num = num >> 8;
    }
    return arr;
  }

  static calculatePassword(keyData: Uint8Array, seconds: number, digits: number): string {
    let timeStep = Math.floor(seconds / 30)
    let timeData: Uint8Array = AuthDataStore.numToUint8Array(timeStep)

    let hmac = cryptoFramework.createMac("SHA1")
    let key = cryptoFramework.createSymKeyGenerator("HMAC").convertKeySync({ data: keyData })
    hmac.initSync(key)
    hmac.updateSync({ data: timeData })
    let result = hmac.doFinalSync()
    let offset = result.data[result.data.length - 1] & 0x0f
    let buf = buffer.alloc(4)
    buf[0] = result.data[offset] & 0x7f
    buf[1] = result.data[offset+1] & 0xff
    buf[2] = result.data[offset+2] & 0xff
    buf[3] = result.data[offset+3] & 0xff
    let value = buf.readUInt32BE()
    if (digits != 5) {
      // TOTP 标准算法
      return (value % Math.pow(10, digits)).toString().padStart(digits, "0")
    }
    // Steam 算法
    // [50, 51, 52, 53, 54, 55, 56, 57, 66, 67, 68, 70, 71, 72, 74, 75, 77, 78, 80, 81, 82, 84, 86, 87, 88, 89]
    const codes = ["2", "3", "4", "5", "6", "7", "8", "9",
      "B", "C", "D", "F", "G", "H", "J", "K", "M", "N", "P", "Q", "R", "T", "V", "W", "X", "Y"]
    let steamResult = ""
    for (let i = 0; i < 5; i++) {
      const element = codes[value%codes.length];
      steamResult += element
      value = Math.floor(value / codes.length)
    }
    return steamResult
  }

  generatePassword(authdata: AuthData): string {
    let keyData: Uint8Array = AuthDataStore.base32Decode(authdata.secret)
    let seconds = systemDateTime.getTime(false) / 1000
    return AuthDataStore.calculatePassword(keyData, seconds, authdata.digits)
  }

  refreshAllPassword() {
    for (let i = 0; i < this.items.length; i++) {
      let item = this.items[i]
      item.password = this.generatePassword(item)
    }
    this.notifyChanged()
  }

  findAuthItem(uuid: string): number {
    let index = -1
    for (let i = 0; i < this.items.length; i++) {
      if (uuid == this.items[i].uuid) {
        index = i
        break
      }
    }
    return index
  }

  removeAuthItem(uuid: string) {
    let index = this.findAuthItem(uuid)
    if (index < 0) {
      return
    }
    let item = this.items[index]
    this.kvStore?.delete(this.buildStorageKey(item.uuid))
    this.items.splice(index, 1)
    this.reindexOrders()
    this.notifyChanged()
  }

  saveAuthItem(uuid: string) {
    let index = this.findAuthItem(uuid)
    if (index < 0) {
      return
    }
    this.persistAuthItem(this.items[index])
    this.notifyChanged()
  }

  updateTokenIconPath(uuid: string, tokenIconPath: string) {
    let index = this.findAuthItem(uuid)
    if (index < 0) {
      return
    }
    this.items[index].tokenIconPath = tokenIconPath
    this.saveAuthItem(uuid)
  }

  addGoogleAuthItem(data: string) {
    let base64 = new util.Base64Helper()
    let bytes = base64.decodeSync(data, util.Type.BASIC_URL_SAFE)
    let payload = googleapi.MigrationPayload.decode(bytes)
    for (let index = 0; index < payload.otpParameters.length; index++) {
      let parameter = payload.otpParameters[index]
      if (parameter.type == googleapi.MigrationPayload.OtpType.OTP_TYPE_HOTP) {
        continue
      }

      let authdata: AuthData = new AuthData()
      authdata.alias = parameter.name!
      authdata.issuer = parameter.issuer!
      authdata.account = parameter.name!
      authdata.secret = AuthDataStore.base32Encode(parameter.secret!)
      authdata.digits = parameter.digits == googleapi.MigrationPayload.DigitCount.DIGIT_COUNT_EIGHT ? 8 : 6
      authdata.external = ""
      authdata.tokenIconPath = ""
      authdata.uuid = AuthDataStore.computeAuthUuid(authdata.issuer, authdata.account, authdata.secret)
      this.appendAuthItem(authdata)
    }
    this.notifyChanged()
  }

  addAuthItem(data: string) {
    let authURI = new uri.URI(data.trim())
    if (authURI.scheme == "otpauth-migration") {
      this.addGoogleAuthItem(authURI.getQueryValue("data"))
      return
    }
    if (authURI.scheme != "otpauth" || authURI.host != "totp") {
      throw new Error(getLocalizedString($r('app.string.base_invalid_scheme_format'),
        `${authURI.scheme}://${authURI.host}`));
    }
    let secret = authURI.getQueryValue("secret")
    let issuer = authURI.getQueryValue("issuer")
    let digits = authURI.getQueryValue("digits")
    let path = authURI.path
    if (path.startsWith("/")) {
      path = path.substring(1)
    }
    let colon = path.indexOf(":")
    let account = path.substring(colon + 1)
    if (colon > 0 && issuer == null) {
      issuer = path.substring(0, colon)
    }
    let authdata: AuthData = new AuthData()
    authdata.alias = issuer ?? account
    authdata.issuer = issuer ?? ""
    authdata.account = account
    authdata.secret = secret
    authdata.digits = digits == "8" ? 8 : digits == "7" ? 7 : 6
    authdata.external = ""
    authdata.tokenIconPath = ""
    if (issuer.toLowerCase() == "steam") {
      authdata.digits = 5
    }
    authdata.uuid = AuthDataStore.computeAuthUuid(authdata.issuer, authdata.account, authdata.secret)
    this.appendAuthItem(authdata)
    this.notifyChanged()
  }

  recoverAuthItem(data: string): [number, number] {
    let result = JSON.parse(data) as Array<AuthData>
    if (!result) {
      throw new Error(getLocalizedString($r('app.string.base_unknown_file_format')))
    }
    for (let index = 0; index < result.length; index++) {
      const element = result[index];
      Object.entries(element).forEach((pair: [string, string]) => {
        if (pair[0] == 'password' || pair[0] == 'tokenIconPath' || pair[0] == 'uuid' || pair[0] == 'order') {
          return;
        }
        if (pair[1] == undefined) {
          throw new Error(getLocalizedString($r('app.string.base_recover_item_missing_format'), index, pair[0]))
        }
      })
    }
    let hasExist = 0;
    let total = result.length;
    for (let index = 0; index < result.length; index++) {
      let element = result[index]
      if (element.uuid == undefined || element.uuid == "") {
        element.uuid = AuthDataStore.computeAuthUuid(element.issuer, element.account, element.secret)
      }
      if (element.order == undefined) {
        element.order = this.items.length
      }
      if (this.containsUuid(element.uuid)) {
        hasExist++;
        continue
      }
      this.appendAuthItem(element)
    }
    this.notifyChanged()
    return [hasExist, total];
  }

  addOneAuthItem(data: AuthData, externalObject?: Object) {
    if (externalObject) {
      data.external = JSON.stringify(externalObject)
    }
    data.uuid = AuthDataStore.computeAuthUuid(data.issuer, data.account, data.secret)
    this.appendAuthItem(data)
    this.notifyChanged()
  }

  async replaceAuthItems(newItems: AuthData[]) {
    let currentKeys = this.items.map((item) => this.buildStorageKey(item.uuid))
    let entries: Array<distributedKVStore.Entry> = []
    let nextItems: AuthData[] = []
    //用来去重
    let seen = new Set<string>()
    for (let i = 0; i < newItems.length; i++) {
      let item = newItems[i]
      item.uuid = item.uuid == "" ? AuthDataStore.computeAuthUuid(item.issuer, item.account, item.secret) : item.uuid
      if (seen.has(item.uuid)) {
        continue
      }
      //记录已见过的uuid
      seen.add(item.uuid)
      item.order = nextItems.length
      nextItems.push(item)
      let authString = JSON.stringify(item)
      entries.push({
        key: this.buildStorageKey(item.uuid),
        value: {
          type: distributedKVStore.ValueType.STRING,
          value: authString,
        }
      })
    }
    let nextKeySet = new Set<string>()
    entries.forEach((entry) => nextKeySet.add(entry.key))
    let deleteKeys = currentKeys.filter((key) => !nextKeySet.has(key))
    await this.kvStore?.putBatch(entries)
    if (deleteKeys.length > 0) {
      await this.kvStore?.deleteBatch(deleteKeys)
    }
    this.items = nextItems
    this.notifyChanged()
  }
}

export class PromptParams<T> {
  private ctx?: UIContext
  private content?: ComponentContent<PromptParams<T>>
  public data: T
  public autoCancel: boolean = true

  constructor(ctx: UIContext, builder: WrappedBuilder<[PromptParams<T>]>, data: T) {
    this.ctx = ctx
    this.data = data
    this.content = new ComponentContent(this.ctx, builder, this);
  }

  open() {
    this.ctx?.getPromptAction().openCustomDialog(this.content, new Object(this))
  }

  close() {
    this.ctx?.getPromptAction().closeCustomDialog(this.content)
  }
}
