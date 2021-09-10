package main

import (
	"fmt"

	"github.com/pulumi/pulumi-aws/sdk/v4/go/aws/apigatewayv2"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi/config"
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		stack := ctx.Stack()
		// caller, err := aws.GetCallerIdentity(ctx, nil, nil)
		// if err != nil {
		// 	return err
		// }

		// API Gateway
		apigw, err := apigatewayv2.NewApi(ctx, fmt.Sprintf("di-%s", stack), &apigatewayv2.ApiArgs{
			Name:         pulumi.String(fmt.Sprintf("di-%s", stack)),
			ProtocolType: pulumi.String("HTTP"),
		})
		if err != nil {
			return err
		}

		_, err = apigatewayv2.NewStage(ctx, "stagev2", &apigatewayv2.StageArgs{
			ApiId:      apigw.ID(),
			Name:       pulumi.String("$default"),
			AutoDeploy: pulumi.Bool(true),
		})

		if err != nil {
			return err
		}

		// Authorizer
		conf := config.New(ctx, "")
		issuer := conf.Require("issuer")
		aud := conf.Require("aud")

		_, err = apigatewayv2.NewAuthorizer(ctx, "google", &apigatewayv2.AuthorizerArgs{
			ApiId:           apigw.ID(),
			Name:            pulumi.String("google"),
			AuthorizerType:  pulumi.String("JWT"),
			IdentitySources: pulumi.ToStringArray([]string{"$request.header.Authorization"}),
			JwtConfiguration: &apigatewayv2.AuthorizerJwtConfigurationArgs{
				Issuer:    pulumi.String(issuer),
				Audiences: pulumi.ToStringArray([]string{aud}),
			},
		})
		if err != nil {
			return err
		}

		return nil
	})
}
