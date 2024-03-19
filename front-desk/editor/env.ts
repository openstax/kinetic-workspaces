const IS_STAGING = window.location.host.match(/sandbox/)

const ENV = {
    IS_STAGING,
    KINETIC_URL: `https://${IS_STAGING ? 'staging.' : ''}kinetic.openstax.org`
}

Object.freeze(ENV)

export { ENV }
