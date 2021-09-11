package main

import (
	"fmt"

	"github.com/pulumi/pulumi-aws/sdk/v4/go/aws/acm"
	"github.com/pulumi/pulumi-aws/sdk/v4/go/aws/apigatewayv2"
	"github.com/pulumi/pulumi-aws/sdk/v4/go/aws/route53"
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

		releaseStage, err := apigatewayv2.NewStage(ctx, "stagev2", &apigatewayv2.StageArgs{
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

		// DNS
		r53zoneid := conf.Require("r53zoneid")

		cert, err := acm.NewCertificate(ctx, "cert", &acm.CertificateArgs{
			DomainName:       pulumi.String("di8.blanktech.net"),
			ValidationMethod: pulumi.String("DNS"),
		})
		if err != nil {
			return err
		}

		validationRecord, err := route53.NewRecord(ctx, "wwww", &route53.RecordArgs{
			AllowOverwrite: pulumi.Bool(true),
			Name:           cert.DomainValidationOptions.Index(pulumi.Int(0)).ResourceRecordName().Elem(),
			Type:           cert.DomainValidationOptions.Index(pulumi.Int(0)).ResourceRecordType().Elem(),
			Records:        pulumi.StringArray{cert.DomainValidationOptions.Index(pulumi.Int(0)).ResourceRecordValue().Elem()},
			Ttl:            pulumi.IntPtr(60),
			ZoneId:         pulumi.String(r53zoneid),
		})
		if err != nil {
			return err
		}

		validation, err := acm.NewCertificateValidation(ctx, "certValidation", &acm.CertificateValidationArgs{
			CertificateArn: cert.Arn,
		})
		if err != nil {
			return err
		}

		domainName, err := apigatewayv2.NewDomainName(ctx, "domain", &apigatewayv2.DomainNameArgs{
			DomainName: pulumi.String("di8.blanktech.net"),
			DomainNameConfiguration: &apigatewayv2.DomainNameDomainNameConfigurationArgs{
				CertificateArn: cert.Arn,
				EndpointType:   pulumi.String("REGIONAL"),
				SecurityPolicy: pulumi.String("TLS_1_2"),
			},
		}, pulumi.DependsOn([]pulumi.Resource{validation, validationRecord}))
		if err != nil {
			return err
		}

		_, err = apigatewayv2.NewApiMapping(ctx, "mapping", &apigatewayv2.ApiMappingArgs{
			ApiId:      apigw.ID(),
			DomainName: domainName.ID(),
			Stage:      releaseStage.ID(),
		})
		if err != nil {
			return err
		}

		_, err = route53.NewRecord(ctx, "dnsToCustomDomain", &route53.RecordArgs{
			Name:   pulumi.String("di8.blanktech.net"),
			Type:   pulumi.String("A"),
			ZoneId: pulumi.String(r53zoneid),
			Aliases: &route53.RecordAliasArray{
				&route53.RecordAliasArgs{
					EvaluateTargetHealth: pulumi.Bool(true),
					Name:                 domainName.DomainNameConfiguration.TargetDomainName().Elem(),
					ZoneId:               domainName.DomainNameConfiguration.HostedZoneId().Elem(),
				},
			},
		})
		if err != nil {
			return err
		}

		return nil
	})
}
