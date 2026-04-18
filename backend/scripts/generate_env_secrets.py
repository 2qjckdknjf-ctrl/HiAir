import argparse
import secrets


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate secure random secrets for backend environment variables.",
    )
    parser.add_argument(
        "--jwt-bytes",
        type=int,
        default=48,
        help="Random bytes for JWT_SECRET before base64url encoding (default: 48).",
    )
    parser.add_argument(
        "--admin-bytes",
        type=int,
        default=24,
        help="Random bytes for NOTIFICATION_ADMIN_TOKEN (default: 24).",
    )
    parser.add_argument(
        "--webhook-bytes",
        type=int,
        default=32,
        help="Random bytes for SUBSCRIPTION_WEBHOOK_SECRET (default: 32).",
    )
    args = parser.parse_args()

    jwt_secret = secrets.token_urlsafe(args.jwt_bytes)
    admin_token = secrets.token_urlsafe(args.admin_bytes)
    webhook_secret = secrets.token_urlsafe(args.webhook_bytes)

    print("# Generated HiAir backend secrets")
    print(f"JWT_SECRET={jwt_secret}")
    print(f"NOTIFICATION_ADMIN_TOKEN={admin_token}")
    print(f"SUBSCRIPTION_WEBHOOK_SECRET={webhook_secret}")
    print("")
    print("# Paste into your .env (do not commit real values).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
