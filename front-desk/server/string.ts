
export function decodeVar(str: string) {
    return decodeURIComponent(str.replace(/\+/g, ' '))
}

// ensure starts with alpha so it works
// for subdomain or unix login
export function randomString(length = 12) {
    const digits = '23456789'
    const alpha = 'abcdefghijkmnopqrstuvwxyz'
    let result = alpha.charAt(Math.floor(Math.random() * alpha.length))
    const characters = alpha + digits;
    for (let i = 0; i < length - 1; i++){
        result += characters.charAt(Math.floor(Math.random() * characters.length));
    }
    return result;
}

