# == Define: pulp::repo
#
define pulp::repo (
  $repo_id = $title,
  $command = 'present',
  $display_name = '',
  $description = '',
  $note = '',
  $feed = '',
  $validate = '',
  $skip = '',
  $feed_ca_cert = '',
  $verify_feed_ssl = '',
  $feed_cert = '',
  $feed_key = '',
  $proxy_host = '',
  $proxy_port = '',
  $proxy_user = '',
  $proxy_pass = '',
  $max_downloads = '',
  $max_speed = '',
  $remove_missing = '',
  $retain_old_count = '',
  $relative_url = '',
  $serve_http = '',
  $serve_https = '',
  $checksum_type = '',
  $gpg_key = '',
  $host_ca = '',
  $auth_ca = '',
  $auth_cert = '',
  $schedule_plan = '',
  $always_renew_session = true
) {

  validate_string($repo_id)
  validate_string($command)
  validate_string($display_name)
  validate_string($description)
  validate_string($note)
  validate_string($feed)
  validate_re($validate, ['^true|false|$'])
  validate_string($skip)
  validate_string($feed_ca_cert)
  validate_re($verify_feed_ssl, ['^true|false|$'])
  validate_string($feed_cert)
  validate_string($feed_key)
  validate_string($proxy_host)
  validate_string($proxy_port)
  validate_string($proxy_user)
  validate_string($proxy_pass)
  validate_re($max_downloads, '\d*')
  validate_re($max_speed, '\d*')
  validate_re($remove_missing, ['^true|false|$'])
  validate_re($retain_old_count, '\d*')
  validate_string($relative_url)
  validate_bool($serve_http)
  validate_bool($serve_https)
  validate_string($checksum_type)
  validate_string($gpg_key)
  validate_string($host_ca)
  validate_string($auth_ca)
  validate_string($auth_cert)
  validate_string($schedule_plan)
  validate_bool($always_renew_session)

  case $serve_http {
    true: {
      $_serve_http = 'true'
    }
    false: {
      $_serve_http = 'false'
    }
    default: {
      fail('invalid value for param serve_http')
    }
  }

  case $serve_https {
    true: {
      $_serve_https = 'true'
    }
    false: {
      $_serve_https = 'false'
    }
    default: {
      fail('invalid value for param serve_https')
    }
  }


  case $command {
    'present': {
      $cmd = 'create'
      $unless = "/usr/bin/pulp-admin repo list --fields=Id | grep -c '^Id:\s*${repo_id}\$'"
      $onlyif = '/bin/true'
    }
    'update': {
      $cmd = 'update'
      $unless = '/bin/false'
      $onlyif = '/bin/true'
    }
    'absent': {
      $cmd = 'delete'
      $unless = '/bin/false'
      $onlyif = "/usr/bin/pulp-admin repo list --fields=Id | grep -c '^Id:\s*${repo_id}\$'"
    }
    default: {
      fail("Unsupported command: ${command}!")
    }
  }

  if $always_renew_session {
    exec {"pulp_renew_session_for_${repo_id}":
      command   => "/usr/bin/pulp-admin login -u ${pulp::server::default_login} -p ${pulp::server::default_password}",
      logoutput => true,
      before    => Exec["manage_repo_${repo_id}"],
      unless    => '/usr/bin/pulp-admin repo list --fields=Id',
    }
  }

  if ! empty($note) {
    $_note = "--note='${note}'"
  }
  else {
    $_note = ''
  }

  if ! empty($skip) {
    $_skip = "--skip='${_skip}'"
  }
  else {
    $_skip = ''
  }

  case $command {
    'absent': {
      $pulp_admin_params = "--repo-id='${repo_id}'"
    }
    'present', 'update': {
      $pulp_admin_params = "\
      ${_note} ${_skip} \
      --repo-id='${repo_id}' --display-name='${display_name}' --description='${description}' \
      --feed='${feed}' --validate='${validate}' \
      --feed-ca-cert='${feed_ca_cert}' --verify-feed-ssl='${verify_feed_ssl}' --feed-cert='${feed_cert}' --feed-key='${feed_key}' \
      --proxy-host='${proxy_host}' --proxy-port='${proxy_port}' --proxy-user='${proxy_user}' --proxy-pass='${proxy_pass}' \
      --max-downloads='${max_downloads}' --max-speed='${max_speed}' \
      --remove-missing='${remove_missing}' --retain-old-count='${retain_old_count}' \
      --relative-url='${relative_url}' --serve-https='${_serve_https}' --serve-http='${_serve_http}' --checksum-type='${checksum_type}' --gpg-key='${gpg_key}' \
      --host-ca='${host_ca}' --auth-ca='${auth_ca}' --auth-cert='${auth_cert}'"
    }
    default: {
      fail("Unsupported command: ${command}!")
    }
  }

  exec {"manage_repo_${repo_id}":
    command   => "/usr/bin/pulp-admin rpm repo ${cmd} ${pulp_admin_params}",
    unless    => $unless,
    onlyif    => $onlyif,
    logoutput => true,
  }

  if ! empty($schedule_plan) and $command != 'absent' {
    exec {"schedule_repo_${repo_id}":
      command   => "/usr/bin/pulp-admin rpm repo sync schedules create --schedule='${schedule_plan}' --repo-id='${repo_id}'",
      unless    => "/usr/bin/pulp-admin rpm repo sync schedules list --repo-id='${repo_id}' | grep '^Schedule:\s*${schedule_plan}'",
      require   => Exec["manage_repo_${repo_id}"],
      logoutput => true,
    }
  }
}
