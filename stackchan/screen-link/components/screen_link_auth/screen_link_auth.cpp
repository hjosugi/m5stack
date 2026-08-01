/*
 * SPDX-License-Identifier: MIT
 *
 * Strong override for the weak development token in M5Stack/StackChan.
 */
#include <sdkconfig.h>
#include <string>

namespace secret_logic {

std::string generate_auth_token()
{
    return CONFIG_SCREEN_LINK_AUTH_TOKEN;
}

}  // namespace secret_logic
