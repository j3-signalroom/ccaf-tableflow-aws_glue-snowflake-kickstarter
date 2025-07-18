#!/usr/bin/env python3


import base64
import hashlib
from datetime import datetime, timedelta, timezone
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
import jwt


__copyright__  = "Copyright (c) 2025 Jeffrey Jonathan Jennings"
__credits__    = ["Jeffrey Jonathan Jennings"]
__license__    = "MIT"
__maintainer__ = "Jeffrey Jonathan Jennings"
__email__      = "j3@thej3.com"
__status__     = "dev"


def __to_public_key_fingerprint(private_key_pem) -> str:
    # Get the raw bytes of public key.
    public_key_raw = private_key_pem.public_key().public_bytes(Encoding.DER, PublicFormat.SubjectPublicKeyInfo)

    # Get the sha256 hash of the raw bytes.
    sha256hash = hashlib.sha256()
    sha256hash.update(public_key_raw)

    # Base64-encode the value and prepend the prefix 'SHA256:'.
    return 'SHA256:' + base64.b64encode(sha256hash.digest()).decode('utf-8')


def generate_jwt(issuer: str, pem, pem_bytes: bytes) -> str:
    """ Generate a JSON Web Token (JWT) using the provided public key fingerprint, private key,
    account, and user information.
    """
    # Get current time in UTC and set JWT lifetime to 59 minutes.
    now = datetime.now(timezone.utc)
    lifetime = timedelta(minutes=59)

    # Create JWT payload
    payload = {
        "iss": f"{issuer}.{__to_public_key_fingerprint(pem)}",
        "sub": issuer,
        "iat": int(now.timestamp()),
        "exp": int((now + lifetime).timestamp())
    }

    return {"jwt": jwt.encode(payload, key=pem_bytes, algorithm="RS256")}
