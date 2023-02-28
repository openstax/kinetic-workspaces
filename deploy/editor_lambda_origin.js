exports.handler = (event, context, callback) => {
  const request = event.Records[0].cf.request;
  const header = request.headers['x-editor-domain']
  if (header) {
    const domain = header[0].value
    const [subDomain] = domain.split('.')

    const domainName = `${subDomain}.compute-1.amazonaws.com`

    Object.assign(request.origin.custom, {
      domainName,
      port: 80,
      protocol: 'http',
    })

    request.headers['host'] = [{ key: 'Host', value: domain}];
  }

  callback(null, request);
};
