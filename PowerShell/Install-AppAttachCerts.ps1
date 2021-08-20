invoke-webrequest https://sefslogixprof1.blob.core.windows.net/wvd/WVDContosoAppAttach.crt -OutFile WVDContosoAppAttach.crt

Import-Certificate WVDContosoAppAttach.crt -CertStoreLocation Cert:\LocalMachine\TrustedPeople\ -Confirm:$false