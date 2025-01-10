{ config, lib, ... }:

with lib;

let
  # List of MIME types for media files that most players support
  mediaMimeTypes = [
    # Audio
    "audio/mpeg"
    "audio/x-wav"
    "audio/x-flac"
    "audio/x-aiff"
    "audio/x-m4a"
    "audio/x-ms-wma"
    "audio/x-vorbis+ogg"
    "audio/x-opus+ogg"
    "audio/x-mpegurl"
    "audio/x-scpls"
    "audio/x-matroska"
    "audio/webm"

    # Video
    "video/mp4"
    "video/x-matroska"
    "video/x-msvideo"
    "video/x-ms-wmv"
    "video/x-flv"
    "video/webm"
    "video/quicktime"
    "video/x-m4v"
    "video/x-ogm"
    "video/x-theora+ogg"
    "video/x-dv"
    "video/mpeg"
    "video/3gpp"
    "video/3gpp2"
    "video/x-mng"
    "video/x-jng"
    "video/x-nut"
    "video/x-ms-asf"
    "video/x-fli"
    "video/x-flc"
    "video/x-ms-wmx"
    "video/x-ms-wvx"
    "video/x-sgi-movie"
    "video/vnd.rn-realvideo"
    "video/vnd.vivo"
    "video/vnd.mpegurl"
    "video/vnd.dlna.mpeg-tts"
    "video/x-flic"
    "video/x-ms-wm"
    "video/x-ms-wmp"
    "video/x-ms-wmv"
    "video/x-ms-wmx"
    "video/x-ms-wvx"
    "video/x-msvideo"
    "video/x-sgi-movie"
  ];
in {
  options = {
    mediaMime = mkOption {
      type = types.str;
      default = "mpv.desktop";
      description = "The desktop file of the media player to use for all media MIME types.";
    };
  };

  config = {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = listToAttrs (map
        (mimeType: nameValuePair mimeType [ config.mediaMime ])
        mediaMimeTypes);
    };
  };
}