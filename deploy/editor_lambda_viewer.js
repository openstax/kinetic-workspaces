exports.handler = (event, context, callback) => {
  const request = event.Records[0].cf.request;
  const domain = request.headers.host[0].value
  if (!domain.startsWith('workspaces')) {
    request.headers['x-editor-domain'] = [{ key: 'X-Editor-Domain', value: domain }]
  }
  callback(null, request);
};
